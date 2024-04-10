import 'dart:async';

import 'package:nyxx/nyxx.dart';

import '../models/match_schedule.dart';
import '../neonbot.dart';
import '../util.dart';
import 'guilds.dart';
import 'tracker/tracker.dart';

const Map<MatchType, String> matchDescriptions = {
  MatchType.playoffs: ("Tournament where you play up to 3 matches (best of 1)\n"
      "Teams alternate banning maps until 3 remain. One team chooses map, and the other chooses starting side"),
  MatchType.match: "Gain 100 points for a win, or 25 for losing",
  MatchType.scrim: "Does not count towards premier score"
};

/// Service for automatically scheduling matches in a guild based on the team region
class MatchScheduler {
  /// Rate at which we update guilds
  static const tickRate = Duration(minutes: 1);

  /// Warmup period before a match.
  static const warmupPeriod = Duration(minutes: 30);

  // Wait until this long to delete a match
  static const deleteAfter = Duration(minutes: 30);

  // How often we should check for new matches
  static const scheduleMatchesInterval = Duration(hours: 1);

  static MatchScheduler get service =>
      _instance ??
      (throw Exception("Match scheduler must be initialized with init()"));
  static MatchScheduler? _instance;

  final NyxxGateway client;
  late final Timer timer;
  final Logger logger = Logger("MatchScheduler");

  final Map<Snowflake, DateTime> _lastUpdated = {};

  MatchScheduler._(this.client) {
    // Schedule a recurring update
    timer = Timer.periodic(tickRate, tryTick);
  }

  static void init(NyxxGateway client) {
    _instance = MatchScheduler._(client);
  }

  void tryTick(Timer timer) async {
    try {
      tick();
    } catch (e, stacktrace) {
      logger.warning("Error in tick(): $e, $stacktrace");
    }
  }

  void tick() async {
    logger.fine("Updating guild match schedules");

    var guilds =
        List.of(client.guilds.cache.values); // Avoid concurrent modification
    for (var guild in guilds) {
      // Get their upcoming events that we scheduled
      dynamic upcomingEvents = (await guild.scheduledEvents.list())
          .where((event) => event.creatorId == NeonBot().userId)
          .toList();

      // Cleanup old events, and possibly start the current match
      upcomingEvents = await cleanupOldEvents(upcomingEvents);
      await startActiveEvents(upcomingEvents);

      // Get the last time we updated this particular guild's events
      var gp = await GuildService().getPreferences(guild.id);
      var lastUpdated =
          _lastUpdated[guild.id] ?? DateTime.fromMicrosecondsSinceEpoch(0);
      var age = DateTime.now().difference(lastUpdated);

      // Schedule new matches from the premier schedule, skipping if we recently
      // updated for this guild
      if (!gp.hasPremierTeam || age < scheduleMatchesInterval) continue;

      var newEvents = await scheduleNewMatches(guild);
      _lastUpdated[guild.id] = DateTime.now();

      // If we did schedule new events, post an announcement
      if (gp.hasSignupRole &&
          gp.hasAnnouncementsChannel &&
          newEvents.isNotEmpty) {
        try {
          var channel =
              await NeonBot().client.channels.get(gp.announcementsChannel);
          if (channel is TextChannel) {
            var announcement = await channel.sendMessage(MessageBuilder(
                content:
                    "${gp.signupRole.roleMention} New matches were scheduled! Check out the Events tab to sign up."));
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
  Future<Iterable<ScheduledEvent>> scheduleNewMatches(Guild guild) async {
    var gp = await GuildService().getPreferences(guild.id);

    // Skip guilds that don't have a team set
    if (!gp.hasPremierTeam || !gp.hasVoiceChannel) return [];

    // Check the upcoming discord events in the guild
    var upcomingEvents = (await guild.scheduledEvents.list())
        .where((event) => event.creatorId == NeonBot().userId)
        .toList();

    // If there's still upcoming matches for the week scheduled, don't bother scheduling more
    if (upcomingEvents.isNotEmpty) return [];

    // Get the upcoming premier schedule for this week
    var matches = (await TrackerApi().getSchedule(await gp.region)).thisWeek;

    Set<ScheduledEvent> newEvents = {};

    nextMatch:
    for (var match in matches) {
      // Try to pair the match to an existing discord event, skipping to the
      // next match if so
      for (var event in upcomingEvents) {
        if (event.scheduledStartTime == match.time) {
          continue nextMatch;
        }
      }

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
        image: await match.map.image,
      ));
      newEvents.add(event);
    }

    return newEvents;
  }

  /// Deletes old events scheduled by neonbot, returning the remaining upcoming events
  ///
  /// [events] is the list of events to check
  Future<Iterable<ScheduledEvent>> cleanupOldEvents(
      Iterable<ScheduledEvent> events) async {
    Set<ScheduledEvent> deleted = {};
    var now = DateTime.now();

    // Cleanup old events that neonbot scheduled, since discord won't auto-delete them.
    // Copy to a new variable to avoid modifying the list we're iterating over
    for (var event in events) {
      if (event.creatorId != NeonBot().userId ||
          event.scheduledEndTime == null) {
        continue;
      }

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
  Future<void> startActiveEvents(Iterable<ScheduledEvent> events) async {
    if (events.isEmpty) return;

    var now = DateTime.now();

    for (var event in events) {
      // Skip events we didn't make or that are already started
      if (event.status != EventStatus.scheduled ||
          event.creatorId != NeonBot().userId) continue;

      var signups = await countEventSignups(event);
      logger.fine("Found $signups signups for event ${event.id}");

      // Can't start a premier match without 5 players
      if (signups < 5) continue;

      // Check if we're in the warmup period, and if so, start the event
      // Todo: Refactor the warmup period into a guild setting?
      if (event.scheduledStartTime.subtract(warmupPeriod).isBefore(now)) {
        logger.fine("In warmup period. Starting event");
        await event
            .update(ScheduledEventUpdateBuilder(status: EventStatus.active));
      }
    }
  }

  /// Counts the number of signups for an event
  ///
  /// Defined as the number of people "interested" in the event
  /// who also have the guild's signup role
  Future<int> countEventSignups(ScheduledEvent event) async {
    var gp = await GuildService().getPreferences(event.guildId);

    if (!gp.hasSignupRole) {
      return 0;
    }

    var interestedMembers = await event
        .listUsers()
        .then((users) => users.map((user) => user.member));

    int signups = interestedMembers
        .where((member) =>
            member != null &&
            member.roles.any((role) => role.id == gp.signupRole))
        .length;

    return signups;
  }
}
