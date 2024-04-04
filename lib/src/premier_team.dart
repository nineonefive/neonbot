import 'package:chaleno/chaleno.dart';
import 'dart:convert';

class PremierTeamDoesntExistException implements Exception {
  final String team;

  const PremierTeamDoesntExistException(this.team);
}

class InvalidRiotIdException implements Exception {
  final String id;

  const InvalidRiotIdException(this.id);
}

class TrackerApiException implements Exception {
  final int statusCode;

  const TrackerApiException(this.statusCode);
}

final riotIdPattern = RegExp(r'^[\w ]+#\w{4,6}$');

class PremierTeam {
  final String uuid;
  final String riotId;
  final String zone;
  final String zoneName;

  int rank = 0;
  int leagueScore = 0;
  String division = '';

  /// Last time we fetched data from tracker.gg
  late DateTime lastUpdated;

  PremierTeam(this.uuid, this.riotId,
      {this.zone = 'NA_US_EAST',
      this.zoneName = 'US East',
      this.rank = 0,
      this.leagueScore = 0,
      this.division = ''}) {
    if (!riotIdPattern.hasMatch(riotId)) {
      throw InvalidRiotIdException(riotId);
    }

    lastUpdated = DateTime.now();
  }

  @override
  String toString() {
    return 'PremierTeam($riotId)';
  }

  @override
  int get hashCode => uuid.hashCode;

  @override
  bool operator ==(Object other) => other is PremierTeam && other.uuid == uuid;
}

class TrackerApi {
  static Future<PremierTeam> searchByRiotId(String riotId) async {
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

  static Future<PremierTeam> searchByUuid(String uuid) async {
    var url = Uri.https('tracker.gg', '/valorant/premier/teams/$uuid');

    var parser = await Chaleno().load(url.toString());
    var scriptTags = parser?.getElementsByTagName('script') ?? [];
    for (var scriptTag in scriptTags) {
      // Ignore external scripts like cloudflare
      if (scriptTag.src == null) {
        var text = scriptTag.innerHTML ?? "";
        if (text.contains("window.__INITIAL_STATE__ = ")) {
          text = text.replaceAll("window.__INITIAL_STATE__ = ", "");
          var data = json.decode(text)["valorantPremier"]["detailedRoster"]
              as Map<String, dynamic>;

          return PremierTeam(
            data["id"],
            data["name"],
            zone: data["zone"],
            zoneName: data["zoneName"],
            rank: data["rank"],
            leagueScore: data["leagueScore"],
            division: data["divisionName"],
          );
        }
      }
    }

    throw TrackerApiException(404);
  }
}
