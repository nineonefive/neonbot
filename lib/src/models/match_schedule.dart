import '../style.dart';
import 'premier_team.dart';

enum MatchType {
  scrim("Scrim", Duration(hours: 1), Duration(hours: 1)),
  match("Match", Duration(hours: 1), Duration(hours: 1)),
  playoffs("Playoffs", Duration(minutes: 15), Duration(hours: 2));

  const MatchType(this.name, this.queueWindow, this.expectedDuration);

  final String name;
  final Duration queueWindow;
  final Duration expectedDuration;
}

class Match {
  final MatchType matchType;
  final DateTime time;
  final ValorantMap map;

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

  @override
  String toString() {
    if (matchType == MatchType.playoffs) {
      return "Playoffs @ $time";
    } else {
      return "${map.name} ${matchType.name} @ $time";
    }
  }
}

class MatchSchedule {
  final List<Match> matches;
  late final DateTime lastUpdated;

  MatchSchedule(this.matches) {
    matches.sort((a, b) => a.time.compareTo(b.time));
    lastUpdated = DateTime.now();
  }

  Iterable<Match> get upcomingMatches =>
      matches.where((m) => m.time.isAfter(DateTime.now()));

  Iterable<Match> get thisWeek {
    var nextTuesday = DateTime.now()
        .subtract(Duration(days: DateTime.now().weekday - 1))
        .add(Duration(days: 8));
    return upcomingMatches.where((m) => m.time.isBefore(nextTuesday));
  }
}
