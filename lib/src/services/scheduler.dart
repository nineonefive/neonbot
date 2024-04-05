import 'dart:async';

import 'package:nyxx/nyxx.dart';

import '../models/match_schedule.dart';
import '../neonbot.dart';
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
    Future.delayed(Duration(seconds: 1), tick);
    timer = Timer(Duration(minutes: 5), tick);
  }

  static void init(NyxxGateway client) {
    _instance = MatchScheduler._(client);
  }

  void tick() async {
    logger.info("Updating guild match schedules");

    var guilds = List.of(client.guilds.cache.values);
    for (var guild in guilds) {
      var lastUpdated =
          _lastUpdated[guild.id] ?? DateTime.fromMicrosecondsSinceEpoch(0);
      var age = DateTime.now().difference(lastUpdated);

      // Skip guilds that have been recently updated, as the premier schedule doesn't change
      // that often
      if (age < const Duration(hours: 1)) {
        continue;
      }

      await scheduleMatches(guild);
      _lastUpdated[guild.id] = DateTime.now();
    }
  }

  /// Schedule upcoming matches for [guild] as server events
  Future<List<ScheduledEvent>> scheduleMatches(Guild guild) async {
    List<ScheduledEvent> newEvents = [];
    var gp = await GuildSettings.service.getForGuild(guild.id);
    var team = await gp.premierTeam;

    // Skip guilds that don't have a team set
    if (team == null) {
      return newEvents;
    }

    var matchEvents = (await guild.scheduledEvents.list())
        .where((event) => event.creatorId == NeonBot.instance.botUser.id)
        .toList()
      ..sort((a, b) => a.scheduledStartTime.compareTo(b.scheduledStartTime));

    // We already have some scheduled events, so wait to schedule more
    if (matchEvents.isNotEmpty) {
      return newEvents;
    }

    var schedule = await TrackerApi.service.getSchedule(team.zone);
    var matches = schedule.thisWeek;

    for (var match in matches) {
      bool alreadyScheduled = false;
      for (var event in matchEvents) {
        if (event.scheduledStartTime == match.time) {
          alreadyScheduled = true;
          break;
        }
      }

      if (alreadyScheduled) {
        continue;
      }

      var name = (match.matchType == MatchType.playoffs)
          ? "Playoffs"
          : "${match.matchType.name} (${match.map.name})";

      var event = await guild.scheduledEvents.create(ScheduledEventBuilder(
          name: name,
          channelId: gp.voiceChannel,
          scheduledStartTime: match.time,
          scheduledEndTime: match.time.add(const Duration(hours: 1)),
          privacyLevel: PrivacyLevel.guildOnly,
          type: ScheduledEntityType.voice,
          image: await match.map.image));
      newEvents.add(event);
    }

    return newEvents;
  }
}
