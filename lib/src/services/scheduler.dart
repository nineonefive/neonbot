import 'dart:async';

import 'package:nyxx/nyxx.dart';

import '../models/match_schedule.dart';
import '../neonbot.dart';
import '../util.dart';
import 'preferences.dart';
import 'tracker.dart';

const Map<MatchType, String> matchDescriptions = {
  MatchType.playoffs: ("Tournament where you play up to 3 matches (best of 1)\n"
      "Teams alternate banning maps until 3 remain. One team chooses map, and the other chooses starting side"),
  MatchType.match: "Gain 100 points for a win, or 25 for losing",
  MatchType.scrim: "Does not count towards premier score"
};

/// Service for automatically scheduling matches in a guild based on the team region
class MatchScheduler {
  /// Rate at which we update guilds
  static const tickRate = Duration(minutes: 5);

  /// Warmup period before a match.
  static const warmupPeriod = Duration(minutes: 30);

  // Wait until this long to delete a match
  static const deleteAfter = Duration(minutes: 30);

  static MatchScheduler get service =>
      _instance ??
      (throw Exception("Match scheduler must be initialized with init()"));
  static MatchScheduler? _instance;

  final NyxxGateway client;
  late final Timer timer;
  final Logger logger = Logger("MatchScheduler");

  final Map<Snowflake, DateTime> _lastUpdated = {};

  MatchScheduler._(this.client) {
    // Schedule an update every 5 minutes and also right now
    Future.delayed(Duration(seconds: 3), () => tryTick(null));
    timer = Timer.periodic(tickRate, tryTick);
  }

  static void init(NyxxGateway client) {
    _instance = MatchScheduler._(client);
  }

  void tryTick(Timer? timer) async {
    try {
      tick();
    } catch (e) {
      if (e is TrackerApiException) {
        if (e.statusCode == 403) {
          logger.warning(
              "Cloud flare is stopping us from retrieving match schedule");
        } else {
          logger.warning("Received tracker error ${e.statusCode}");
        }
      }
    }
  }

  void tick() async {
    logger.info("Updating guild match schedules");

    var guilds = List.of(client.guilds.cache.values);
    for (var guild in guilds) {
      var gp = await GuildSettings.service.getForGuild(guild.id);
      var lastUpdated =
          _lastUpdated[guild.id] ?? DateTime.fromMicrosecondsSinceEpoch(0);
      var age = DateTime.now().difference(lastUpdated);

      var upcomingEvents = (await guild.scheduledEvents.list())
          .where((event) => event.creatorId == NeonBot.instance.botUser.id)
          .toList();

      // Cleanup old events, and possibly start the current match
      upcomingEvents = await cleanupOldEvents(upcomingEvents);
      await maybeStartCurrentMatch(upcomingEvents);

      // Skip guilds that have been recently updated, as the premier schedule doesn't change
      // that often
      if (!gp.hasPremierTeam || age < const Duration(hours: 1)) continue;

      var newEvents = await scheduleNewMatches(guild);
      _lastUpdated[guild.id] = DateTime.now();

      if (gp.hasTagForSignupRole &&
          gp.hasAnnouncementsChannel &&
          newEvents.isNotEmpty) {
        try {
          var channel = await NeonBot.instance.client.channels
              .get(gp.announcementsChannel);
          if (channel is TextChannel) {
            var announcement = await channel.sendMessage(MessageBuilder(
                content:
                    "${gp.tagForSignupRole.roleMention} New matches were scheduled! Check out the Events tab to sign up."));
            await announcement.react(ReactionBuilder(name: "✅", id: null));
          }
        } catch (e) {
          // Our announcements channel is invalid if we get an error.
          // We just won't post if we get one
        }
      }
    }
  }

  /// Schedule upcoming matches for [guild] as server events
  Future<List<ScheduledEvent>> scheduleNewMatches(Guild guild) async {
    List<ScheduledEvent> newEvents = [];
    var gp = await GuildSettings.service.getForGuild(guild.id);

    // Skip guilds that don't have a team set
    if (!gp.hasPremierTeam || !gp.hasVoiceChannel) return newEvents;

    var upcomingEvents = (await guild.scheduledEvents.list())
        .where((event) => event.creatorId == NeonBot.instance.botUser.id)
        .toList();

    // At this point, matchEvents only contains upcoming events that neonbot scheduled.
    // If there's still upcoming matches for the week, don't bother scheduling more
    if (upcomingEvents.isNotEmpty) return newEvents;

    // Get the upcoming premier schedule
    var schedule = await TrackerApi.service.getSchedule(await gp.zone);
    var matches = schedule.thisWeek;

    for (var match in matches) {
      // Skip any matches that already have an associated discord event, as
      // we don't want to reschedule.
      bool alreadyScheduled = false;
      for (var event in upcomingEvents) {
        if (event.scheduledStartTime == match.time) {
          alreadyScheduled = true;
          break;
        }
      }

      if (alreadyScheduled) continue;

      if (match.matchType == MatchType.unknown) {
        throw Exception("Tried scheduling an event for an unknown match");
      }

      var name = (match.matchType == MatchType.playoffs)
          ? "Playoffs"
          : "${match.matchType.name} (${match.map.name})";

      var description =
          "**Queue window**: ${match.matchType.queueWindow.formatted}\n"
          "${matchDescriptions[match.matchType]}";

      var event = await guild.scheduledEvents.create(ScheduledEventBuilder(
          name: name,
          description: description,
          channelId: gp.voiceChannel,
          scheduledStartTime: match.time,
          scheduledEndTime: match.time.add(match.matchType.expectedDuration),
          privacyLevel: PrivacyLevel.guildOnly,
          type: ScheduledEntityType.voice,
          image: await match.map.image));
      newEvents.add(event);
    }

    return newEvents;
  }

  /// Deletes old events scheduled by neonbot, returning the remaining upcoming events
  ///
  /// [events] is the list of events to check
  Future<List<ScheduledEvent>> cleanupOldEvents(
      List<ScheduledEvent> events) async {
    Set<ScheduledEvent> deleted = {};
    var now = DateTime.now();

    // Cleanup old events that neonbot scheduled, since discord won't auto-delete them.
    // Copy to a new variable to avoid modifying the list we're iterating over
    for (var event in events) {
      if (event.creatorId != NeonBot.instance.botUser.id ||
          event.scheduledEndTime == null) continue;

      var isFinished = event.scheduledEndTime!.isBefore(now);
      var isVeryOld = event.scheduledEndTime!.add(deleteAfter).isBefore(now);

      // Update event statuses, possibly delete super old ones
      if (isFinished) {
        var newEventStatus = switch (event.status) {
          EventStatus.scheduled => EventStatus.cancelled,
          EventStatus.active => EventStatus.completed,
          _ => event.status
        };

        var newEvent = await event
            .update(ScheduledEventUpdateBuilder(status: newEventStatus));

        // Cleanup very old events (well after their scheduled end time)
        if (isVeryOld) {
          await newEvent.delete();
          deleted.add(event);
        }
      }
    }

    // Return surviving events
    return events.where((event) => !deleted.contains(event)).toList();
  }

  /// Finds any matches that have enough signups and starts them if possible
  Future<void> maybeStartCurrentMatch(List<ScheduledEvent> events) async {
    if (events.isEmpty) return;

    var gp = await GuildSettings.service.getForGuild(events.first.guildId);
    var now = DateTime.now();

    for (var event in events) {
      logger.fine("Updating event ${event.id}: ${event.status.name}");
      // Skip events we didn't make or that are already started
      if (event.status != EventStatus.scheduled ||
          event.creatorId != NeonBot.instance.botUser.id) continue;

      // Count the number of signups of people who have the apporpriate role
      var interestedMembers = await event
          .listUsers()
          .then((users) => users.map((user) => user.member));

      logger.fine("Has ${interestedMembers.length} interested members");

      int signups = interestedMembers
          .where((member) =>
              member != null &&
              member.roles.any((role) => role.id == gp.tagForSignupRole))
          .length;

      logger.fine("Has $signups signups");

      // Can't start a premier match without 5 players
      if (signups < 5) continue;

      // Check if we're in the warmup period, and if so, start the event
      if (event.scheduledStartTime.subtract(warmupPeriod).isBefore(now)) {
        logger.fine("In warmup period. Starting event");
        await event
            .update(ScheduledEventUpdateBuilder(status: EventStatus.active));
      }
    }
  }
}
