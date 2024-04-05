import 'dart:convert';

import 'package:chaleno/chaleno.dart';
import 'package:logging/logging.dart';

import '../models/match_schedule.dart';
import '../models/premier_team.dart';

/// Exception for validly formatted riot ids that don't have an
/// associated team.
class PremierTeamDoesntExistException implements Exception {
  final String team;

  const PremierTeamDoesntExistException(this.team);
}

/// Exception for invalidly formatted riot id
class InvalidRiotIdException implements Exception {
  final String id;

  const InvalidRiotIdException(this.id);
}

/// Miscellaneous tracker errors
class TrackerApiException implements Exception {
  final int statusCode;

  const TrackerApiException(this.statusCode);
}

class TrackerApi {
  static final TrackerApi service = TrackerApi._();
  static final riotIdPattern = RegExp(r'^[\w ]+#\w{4,6}$');

  // Maps team id to team
  Map<String, PremierTeam> teamCache = {};

  // Maps region id to upcoming matches
  Map<String, MatchSchedule> scheduleCache = {};
  final Logger logger = Logger("TrackerApi");

  TrackerApi._();

  /// Tries to find a premier team using the [riotId].
  ///
  /// This won't load all data (such as zone, standings). For that, you need
  /// to follow up by searching for the uuid
  Future<PremierTeam> searchByRiotId(String riotId) async {
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
          var team = resultSet["results"][0];
          var uuid = team["id"];
          riotId = team["name"];
          return PremierTeam(uuid, riotId);
        }
      }
    }

    throw PremierTeamDoesntExistException(riotId);
  }

  Future<PremierTeam> searchByUuid(String uuid) async {
    if (teamCache.containsKey(uuid)) {
      var team = teamCache[uuid]!;
      var age = DateTime.now().difference(team.lastUpdated);

      if (team.isLoaded && age < const Duration(minutes: 5)) {
        return team;
      }
    }

    var url = Uri.https('tracker.gg', '/valorant/premier/teams/$uuid');
    var data =
        (await parseTrackerPage(url))["detailedRoster"] as Map<String, dynamic>;
    var team = PremierTeam(
      data["id"],
      data["name"],
      zone: data["zone"],
      zoneName: data["zoneName"],
      rank: data["rank"],
      leagueScore: data["leagueScore"],
      division: data["divisionName"],
    );

    teamCache[team.id] = team;
    return team;
  }

  /// Gets the upcoming matches for the given region [region]
  Future<MatchSchedule> getSchedule(String region) async {
    if (scheduleCache.containsKey(region)) {
      var schedule = scheduleCache[region]!;
      var age = DateTime.now().difference(schedule.lastUpdated);
      if (age < const Duration(hours: 1)) {
        return schedule;
      }
    }

    var url = Uri.https(
        'tracker.gg', '/valorant/premier/standings', {'region': region});
    logger.fine("Fetching schedule for $region at $url");
    var data =
        (await parseTrackerPage(url))["schedules"] as Map<String, dynamic>;
    var matchDicts =
        (data.values.first as Map<String, dynamic>)["events"] as List<dynamic>;
    var matches = matchDicts.whereType<Map<String, dynamic>>().map((m) {
      var matchType = switch (m["typeName"]) {
        "Scrim" => MatchType.scrim,
        "Match" => MatchType.match,
        "Tournament" => MatchType.playoffs,
        _ => throw TrackerApiException(500)
      };

      var time = DateTime.parse(m["startTime"]);
      var map = (matchType == MatchType.playoffs) ? null : m["name"];
      return Match(matchType, time, map);
    }).toList();

    var schedule = MatchSchedule(matches);
    scheduleCache[region] = schedule;
    return schedule;
  }

  Future<Map<String, dynamic>> parseTrackerPage(Uri url) async {
    var parser = await Chaleno().load(url.toString());
    var scriptTags = parser?.getElementsByTagName('script') ?? [];
    for (var scriptTag in scriptTags) {
      // Ignore external scripts like cloudflare
      if (scriptTag.src == null) {
        var text = scriptTag.innerHTML ?? "";
        if (text.contains("window.__INITIAL_STATE__ = ")) {
          text = text.replaceAll("window.__INITIAL_STATE__ = ", "");
          var data = json.decode(text)["valorantPremier"];
          return data;
        }
      }
    }

    throw TrackerApiException(404);
  }
}
