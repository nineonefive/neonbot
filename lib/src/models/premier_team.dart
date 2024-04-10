import '../util.dart';
import 'valorant_regions.dart';

class PremierTeam {
  final String id;
  final String name;
  final Region region;
  final String imageUrl;

  int rank = 0;
  int leagueScore = 0;
  String division = '';

  /// Last time we fetched data from tracker.gg
  late DateTime lastUpdated;

  /// Stores the team's icon
  List<int> _teamIcon = [];
  Future<List<int>> get icon async {
    if (imageUrl.isEmpty) return [];

    if (_teamIcon.isEmpty) {
      _teamIcon = await downloadImage(Uri.parse(imageUrl));
    }

    return _teamIcon;
  }

  PremierTeam(
    this.id,
    this.name, {
    this.region = Region.usEast,
    this.rank = 0,
    this.leagueScore = 0,
    this.division = '',
    this.imageUrl = '',
  }) {
    lastUpdated = DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'region': region.toJson(),
      // Other fields are transient statistics
    };
  }

  static PremierTeam fromJson(Map<String, dynamic> data) {
    var team = PremierTeam(
      data['id'],
      data['name'],
      region: Region.fromJson(data['region']),
      rank: data['rank'] as int? ?? 0,
      leagueScore: data['leagueScore'] as int? ?? 0,
      division: data['division'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
    );

    return team;
  }

  @override
  String toString() {
    return 'PremierTeam($name)';
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
