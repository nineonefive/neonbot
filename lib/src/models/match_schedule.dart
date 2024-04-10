import 'valorant_maps.dart';

enum MatchType {
  scrim("Scrim", Duration(hours: 1), Duration(hours: 2)),
  match("Match", Duration(hours: 1), Duration(hours: 2)),
  playoffs("Playoffs", Duration(minutes: 15), Duration(hours: 3)),
  unknown("Unknown", Duration.zero, Duration.zero);

  const MatchType(this.name, this.queueWindow, this.expectedDuration);

  final String name;
  final Duration queueWindow;
  final Duration expectedDuration;

  static MatchType getByName(String? name) {
    for (var type in values) {
      if (type.name == name) {
        return type;
      }
    }

    if (name == "Tournament") {
      return playoffs;
    }

    return unknown;
  }
}

class Match {
  final MatchType matchType;
  final DateTime startTime;
  final ValorantMap map;

  Match(this.matchType, this.startTime, this.map);

  Map<String, dynamic> toJson() {
    return {
      'matchType': matchType.name,
      'startTime': startTime.toIso8601String(),
      'map': map.name,
    };
  }

  static Match fromJson(Map<String, dynamic> data) {
    return Match(
      MatchType.getByName(data["matchType"]),
      DateTime.parse(data["startTime"]),
      ValorantMap.getByName(data["map"]),
    );
  }

  @override
  String toString() {
    if (matchType == MatchType.playoffs) {
      return "Match(Playoffs @ $startTime)";
    } else {
      return "Match(${map.name} ${matchType.name} @ $startTime)";
    }
  }
}

class MatchSchedule {
  final List<Match> matches;
  late final DateTime lastUpdated;

  MatchSchedule(this.matches) {
    matches.sort((a, b) => a.startTime.compareTo(b.startTime));
    lastUpdated = DateTime.now();
  }

  Iterable<Match> get upcomingMatches =>
      matches.where((m) => m.startTime.isAfter(DateTime.now()));

  Iterable<Match> get thisWeek {
    var nextTuesday = DateTime.now()
        .subtract(Duration(days: DateTime.now().weekday - 1))
        .add(Duration(days: 8));
    return upcomingMatches.where((m) => m.startTime.isBefore(nextTuesday));
  }

  List<Map<String, dynamic>> toJson() {
    return matches.map((m) => m.toJson()).toList();
  }

  static MatchSchedule fromJson(List<Map<String, dynamic>> data) {
    return MatchSchedule(data.map(Match.fromJson).toList());
  }
}
