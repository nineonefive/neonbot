import '../util.dart';

class PremierTeam {
  final String id;
  final String riotId;
  final String zone;
  final String zoneName;

  final String imageUrl;

  int rank = 0;
  int leagueScore = 0;
  String division = '';

  List<int> _imagePng = [];
  Future<List<int>> get imagePng async {
    if (imageUrl.isEmpty) return [];

    if (_imagePng.isEmpty) {
      _imagePng = await downloadImage(Uri.parse(imageUrl));
    }

    return _imagePng;
  }

  /// Last time we fetched data from tracker.gg
  late DateTime lastUpdated;

  PremierTeam(this.id, this.riotId,
      {this.zone = 'NA_US_EAST',
      this.zoneName = 'US East',
      this.rank = 0,
      this.leagueScore = 0,
      this.division = '',
      this.imageUrl = ''}) {
    lastUpdated = DateTime.now();
  }

  @override
  String toString() {
    return 'PremierTeam($riotId)';
  }

  @override
  int get hashCode => id.hashCode;

  @override
  bool operator ==(Object other) => other is PremierTeam && other.id == id;
}

/// Represents a premier team that hasn't been fully downloaded
/// from tracker yet
class PartialPremierTeam {
  static const none = PartialPremierTeam('', '');

  final String id;
  final String name;

  const PartialPremierTeam(this.id, this.name);

  @override
  String toString() {
    return 'PartialPremierTeam($name)';
  }

  @override
  int get hashCode => id.hashCode;

  @override
  bool operator ==(Object other) =>
      other is PartialPremierTeam && other.id == id;
}
