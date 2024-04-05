import 'dart:async';
import 'dart:convert';

import 'package:nyxx/nyxx.dart';

import 'premier_team.dart';
import '../services/db.dart';
import '../services/tracker.dart';

final table = Tables.GuildPreferences;
final logger = Logger("GuildPreferences");

class GuildPreferences {
  final Snowflake guildId;
  PartialPremierTeam partialTeam;
  Snowflake announcementsChannel;
  Snowflake voiceChannel;
  Snowflake tagForSignupRole;

  bool get hasPremierTeam => partialTeam != PartialPremierTeam.none;
  bool get hasAnnouncementsChannel => announcementsChannel != Snowflake.zero;
  bool get hasVoiceChannel => voiceChannel != Snowflake.zero;
  bool get hasTagForSignupRole => tagForSignupRole != Snowflake.zero;

  Future<PremierTeam> get premierTeam async {
    return hasPremierTeam
        ? await TrackerApi.service.searchByUuid(partialTeam.id)
        : throw Exception("Calling get premierTeam on a guild without one set");
  }

  Future<String> get zone async {
    if (!hasPremierTeam) return "NA_US_EAST";
    var team = await premierTeam;
    return team.zone;
  }

  GuildPreferences(this.guildId,
      {this.partialTeam = PartialPremierTeam.none,
      this.announcementsChannel = Snowflake.zero,
      this.voiceChannel = Snowflake.zero,
      this.tagForSignupRole = Snowflake.zero});

  void persistToDb() {
    DatabaseService.service!.execute(
        "UPDATE ${table.name} SET preferences = ? WHERE guildId = ?",
        [toJson(), guildId.value]);
  }

  String toJson() {
    return jsonEncode({
      "guildId": guildId.value,
      "premierTeamId": partialTeam.id,
      "premierTeamName": partialTeam.name,
      "announcementsChannel": announcementsChannel.value,
      "voiceChannel": voiceChannel.value,
      "tagForSignupRole": tagForSignupRole.value
    });
  }

  static GuildPreferences fromJson(String json) {
    var data = jsonDecode(json);
    var team =
        PartialPremierTeam(data["premierTeamId"], data["premierTeamName"]);
    return GuildPreferences(Snowflake(data["guildId"]),
        partialTeam: team,
        announcementsChannel: Snowflake(data["announcementsChannel"]),
        voiceChannel: Snowflake(data["voiceChannel"]),
        tagForSignupRole: Snowflake(data["tagForSignupRole"]));
  }
}
