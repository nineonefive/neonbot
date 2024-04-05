import 'dart:async';
import 'dart:convert';

import 'package:nyxx/nyxx.dart';

import 'models/premier_team.dart';
import 'services/db.dart';
import 'services/tracker.dart';
import 'util.dart' show maybeNullSnowflake;

final table = Tables.GuildPreferences;
final logger = Logger("GuildPreferences");

class GuildPreferences {
  final Snowflake guildId;
  String? premierTeamId;
  Snowflake? announcementsChannel;
  Snowflake? voiceChannel;

  Future<PremierTeam?> get premierTeam async {
    return (premierTeamId != null)
        ? TrackerApi.service.searchByUuid(premierTeamId!)
        : null;
  }

  Future<String?> get zone async {
    var team = await premierTeam;
    return team?.zone;
  }

  GuildPreferences(this.guildId,
      {this.premierTeamId, this.announcementsChannel, this.voiceChannel});

  void persistToDb() {
    DatabaseService.service!.execute(
        "UPDATE ${table.name} SET preferences = ? WHERE guildId = ?",
        [toJson(), guildId.value]);
  }

  String toJson() {
    return jsonEncode({
      "guildId": guildId.value,
      "premierTeam": premierTeamId,
      "announcementsChannel": announcementsChannel?.value,
      "voiceChannel": voiceChannel?.value
    });
  }

  static GuildPreferences fromJson(String json) {
    var data = jsonDecode(json);
    return GuildPreferences(Snowflake(data["guildId"]),
        premierTeamId: data["premierTeam"],
        announcementsChannel: maybeNullSnowflake(data["announcementsChannel"]),
        voiceChannel: maybeNullSnowflake(data["voiceChannel"]));
  }
}
