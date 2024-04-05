import 'premier_team.dart';

enum MatchType {
  scrim("scrim"),
  match("match"),
  playoffs("playoffs");

  const MatchType(this.name);

  final String name;
}

class Match {
  final MatchType matchType;
  final DateTime time;

  // Playoffs won't have a map
  final String? map;

  final String? teamAId;
  final String? teamBId;
  final int teamAScore;
  final int teamBScore;

  String? get winnerId {
    if (teamAScore > teamBScore) {
      return teamAId;
    } else if (teamBScore > teamAScore) {
      return teamBId;
    } else {
      return null;
    }
  }

  bool didTeamWin(PremierTeam team) {
    return team.id == winnerId;
  }

  Match(this.matchType, this.time, this.map,
      {this.teamAId, this.teamBId, this.teamAScore = 0, this.teamBScore = 0});
}

class MatchSchedule {
  final List<Match> matches;
  late final DateTime lastUpdated;

  MatchSchedule(this.matches) {
    lastUpdated = DateTime.now();
  }
}
