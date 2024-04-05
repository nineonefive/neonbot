import 'dart:async';

import 'package:nyxx/nyxx.dart';

import '../models/match_schedule.dart';
import '../neonbot.dart';
import '../util.dart';
import 'preferences.dart';
import 'tracker.dart';

/// Service for automatically scheduling matches in a guild based on the team region
class MatchScheduler {
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
    Future.delayed(Duration(seconds: 3), tryTick);
    timer = Timer(Duration(minutes: 5), tryTick);
  }

  static void init(NyxxGateway client) {
    _instance = MatchScheduler._(client);
  }

  void tryTick() async {
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

      // Skip guilds that have been recently updated, as the premier schedule doesn't change
      // that often
      if (!gp.hasPremierTeam || age < const Duration(hours: 1)) continue;

      var newEvents = await scheduleMatches(guild);
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
  Future<List<ScheduledEvent>> scheduleMatches(Guild guild) async {
    List<ScheduledEvent> newEvents = [];
    var gp = await GuildSettings.service.getForGuild(guild.id);

    // Skip guilds that don't have a team set
    if (!gp.hasPremierTeam) return newEvents;

    var matchEvents = (await guild.scheduledEvents.list())
        .where((event) => event.creatorId == NeonBot.instance.botUser.id)
        .toList();

    // We already have some scheduled events, so wait to schedule more
    if (matchEvents.isNotEmpty) {
      return newEvents;
    }

    var schedule = await TrackerApi.service.getSchedule(await gp.zone);
    var matches = schedule.thisWeek;

    for (var match in matches) {
      // Skip any matches that already have an associated discord event
      bool alreadyScheduled = false;
      for (var event in matchEvents) {
        if (event.scheduledStartTime == match.time) {
          alreadyScheduled = true;
          break;
        }
      }

      if (alreadyScheduled) continue;

      var name = (match.matchType == MatchType.playoffs)
          ? "Playoffs"
          : "${match.matchType.name} (${match.map.name})";

      var description =
          "**Queue window**: ${match.matchType.queueWindow.formatted}\n";

      switch (match.matchType) {
        case MatchType.playoffs:
          description += "\n";
          description +=
              "Tournament where you play up to 3 matches (best of 1)\n";
          description +=
              "Teams alternate banning maps until 3 remain. One team chooses map, and the other chooses starting side";
        case MatchType.scrim:
          description += "Does not count towards premier score";
        case MatchType.match:
          description += "Gain 100 points for a win, or 25 for losing";
        default:
          throw Exception(
              "Unexpected match type when scheduling: ${match.matchType}");
      }

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
}
