class PremierTeam {
  final String id;
  final String riotId;
  final String zone;
  final String zoneName;

  int rank = 0;
  int leagueScore = 0;
  String division = '';

  /// Last time we fetched data from tracker.gg
  late DateTime lastUpdated;

  PremierTeam(this.id, this.riotId,
      {this.zone = 'NA_US_EAST',
      this.zoneName = 'US East',
      this.rank = 0,
      this.leagueScore = 0,
      this.division = ''}) {
    lastUpdated = DateTime.now();
  }

  /// Returns true if the team has been fully fetched from tracker
  bool get isLoaded => rank != 0;

  @override
  String toString() {
    return 'PremierTeam($riotId)';
  }

  @override
  int get hashCode => id.hashCode;

  @override
  bool operator ==(Object other) => other is PremierTeam && other.id == id;
}
