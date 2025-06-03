import 'dart:async';
import 'dart:convert';

import 'package:chaleno/chaleno.dart' show Chaleno;
import 'package:logging/logging.dart';
import 'package:neonbot/src/services/tracker/tracker_worker.dart';

import '../../cache.dart';
import '../../models/match_schedule.dart';
import '../../models/premier_team.dart';
import '../../models/valorant_regions.dart';
import '../../neonbot.dart';
import '../db.dart';
import 'exceptions.dart';

class TrackerApi {
  static const teamCacheTTL = Duration(minutes: 10);
  static const teamCacheSize = 100;
  static const scheduleCacheTTL = Duration(days: 1);
  static const scheduleCacheSize = 25;
  static final riotIdPattern = RegExp(r'^[\w ]+#\w{3,6}$', unicode: true);
  static bool cloudflareMode = false;

  static late final TrackerApi _instance;

  factory TrackerApi() {
    return _instance;
  }

  static void init() {
    _instance = TrackerApi._();
  }

  final Logger logger = Logger("TrackerApi");
  late final TrackerWorker _worker;

  // Maps team uuid to team
  late final Cache<String, PremierTeam> teamCache;

  // Maps region to upcoming matches
  late final Cache<Region, MatchSchedule> scheduleCache;

  TrackerApi._() {
    TrackerWorker.spawn().then((w) {
      _worker = w;
      NeonBot().onShutdown(_worker.close);
    });

    teamCache = Cache(
      ttl: teamCacheTTL,
      maxSize: teamCacheSize,
      retrieve: _searchByUuid,
    );
    scheduleCache = Cache(
      ttl: scheduleCacheTTL,
      maxSize: scheduleCacheSize,
      retrieve: fetchSchedule,
    );
  }

  /// Retrieves a full premier team with id [uuid].
  ///
  /// Will throw a TrackerApiException if the team can't be retrieved
  Future<PremierTeam> getTeam(String uuid) async =>
      (await teamCache.get(uuid))!;

  /// Retrieves the upcoming matches for the given region [region]
  Future<MatchSchedule> getSchedule(Region region) async =>
      (await scheduleCache.get(region))!;

  /// Tries to find a premier team using the [riotId].
  ///
  /// This won't load all data (such as zone, standings). For that, you need
  /// to follow up by searching for the uuid
  Future<PartialPremierTeam> searchByRiotId(String riotId) async {
    if (!riotIdPattern.hasMatch(riotId)) {
      throw InvalidRiotIdException(riotId);
    }

    var url = Uri.https('api.tracker.gg',
        '/api/v1/valorant/search/by-query/$riotId', {'type': 'premier-team'});

    var parser = await Chaleno().load(url.toString());
    var body = parser?.getElementsByTagName('body')?.first.text;
    if (body != null) {
      var data = json.decode(body)["data"];
      for (dynamic resultSet in data["resultSets"]) {
        if (resultSet["type"] == 'premier-team' &&
            resultSet["results"].length == 1) {
          var result = resultSet["results"][0];
          return PartialPremierTeam.fromJson(result);
        }
      }
    }

    throw PremierTeamDoesntExistException(riotId);
  }

  /// Retrieves a team from tracker by their [uuid].
  ///
  /// Throws an error if the team can't be found.
  Future<PremierTeam> _searchByUuid(String uuid) async {
    var url =
        Uri.https('tracker.gg', '/valorant/premier/teams/$uuid').toString();
    var response = await _worker.getValorantPremierData(url);
    if (response == null) {
      logger.shout("Failed to search for team $uuid, response is null");
      throw TrackerApiException(500);
    }

    logger.fine("Got data for team $uuid");
    var data = response["detailedRoster"] as Map<String, dynamic>;

    if (data["id"] == null) throw TrackerApiException(403);

    data['region'] = {'id': data['zone']};
    data["imageUrl"] = data["icon"]["imageUrl"] as String;
    data["division"] = data["divisionName"];
    var team = PremierTeam.fromJson(data);

    logger.fine("Downloaded team $team from tracker");
    return team;
  }

  /// Gets the upcoming matches for the given region [region]
  Future<MatchSchedule> fetchSchedule(Region region) async {
    // First check the database
    var schedule = _getScheduleFromDatabase(region);
    if (schedule.isNotEmpty) {
      return schedule;
    }

    // Download schedule from tracker
    schedule = await downloadSchedule(region);

    // Add all matches to the database if we get any. Cloudflare errors
    // won't reach this point since they'll throw above.
    if (schedule.isNotEmpty) {
      Future(() => updateSchedule(schedule, region));
    }

    return schedule;
  }

  Future<MatchSchedule> downloadSchedule(Region region) async {
    // Download the data with the worker since it's intensive. This avoids hanging
    // other computations in the main event queue
    var url = Uri.https(
            'tracker.gg', '/valorant/premier/standings', {'region': region.id})
        .toString();
    logger.fine("Fetching schedule for $region at $url");
    var response = await _worker.getValorantPremierData(url);

    if (response == null) {
      logger.shout("Received null response for schedule");
      throw TrackerApiException(500);
    }

    // Parse the matches into our appropriate structure. The events are stored under
    // the "events" key, so get that first.
    var data = response["schedules"] as Map<String, dynamic>;
    var matchDicts =
        (data.values.first as Map<String, dynamic>)["events"] as List<dynamic>;
    var matches = matchDicts
        .whereType<Map<String, dynamic>>()
        .map((data) => Match.fromJson({
              'matchType': data['typeName'],
              'startTime': data['startTime'],
              'map': data['name'],
            }))
        .where((m) => m.matchType != MatchType.unknown)
        .toList();

    // Save the match schedule for future calls from other guilds
    var schedule = MatchSchedule(matches);
    return schedule;
  }

  /// Returns all upcoming matches from the database for region [region]
  MatchSchedule _getScheduleFromDatabase(Region region) {
    var table = Tables.premierSchedule;
    var results = DatabaseService.service!.select(
        "SELECT data FROM ${table.name} WHERE region = ? AND startTime > ?",
        [region.id, DateTime.now().millisecondsSinceEpoch]);

    return MatchSchedule(
        results.map((row) => Match.fromJson(jsonDecode(row["data"]))).toList());
  }

  /// Adds all matches from the schedule to the database
  void updateSchedule(MatchSchedule schedule, Region region) {
    if (region == Region.none) {
      throw Exception("Region must not be Region.none");
    }

    if (schedule.isEmpty) {
      return;
    }

    var table = Tables.premierSchedule;
    var stmt = DatabaseService.service!.prepare(
        "INSERT OR IGNORE INTO ${table.name} (region, startTime, data) VALUES (?, ?, ?)");

    for (var match in schedule.matches) {
      stmt.execute([
        region.id,
        match.startTime.millisecondsSinceEpoch,
        jsonEncode(match.toJson()),
      ]);
    }

    stmt.dispose();
  }
}
