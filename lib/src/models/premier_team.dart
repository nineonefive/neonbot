import '../util.dart';
import 'valorant_regions.dart';

class PremierTeam {
  final String id;
  final String riotId;
  final Region region;
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
      {this.region = Region.usEast,
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

  Map<String, String> toJson() {
    return {'id': id, 'name': name};
  }

  static PartialPremierTeam fromJson(Map<String, dynamic>? data) {
    if (data == null || data['id'] == null || data['name'] == null) {
      return none;
    }

    return PartialPremierTeam(data['id'], data['name']);
  }

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
