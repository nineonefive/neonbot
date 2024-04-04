import 'dart:convert';

import 'package:neonbot/src/db.dart';
import 'package:neonbot/src/premier_team.dart';
import 'package:nyxx/nyxx.dart';
import 'package:sqlite3/common.dart';

final table = Tables.GuildPreferences;

class GuildPreferences {
  final Snowflake guildId;
  PremierTeam? _premierTeam;
  Snowflake? announcementsChannel;

  Future<PremierTeam>? teamPromise;

  GuildPreferences(this.guildId,
      {String? premierTeamUuid, Snowflake? announcementsChannel}) {
    // Try to set premier team if we have it saved
    if (premierTeamUuid != null) {
      // Todo: possibly handle error here and log it
      teamPromise = TrackerApi.searchByUuid(premierTeamUuid)
          .then((team) => _premierTeam = team);
    }
  }

  PremierTeam? get premierTeam => _premierTeam;

  void set premierTeam(PremierTeam? team) {
    _premierTeam = team;
    persistToDb();
  }

  void persistToDb() {
    Db.db!.execute("UPDATE ${table.name} SET preferences = ? WHERE guildId = ?",
        [toJson(), guildId.value]);
  }

  String toJson() {
    return jsonEncode({
      "premierTeam": premierTeam?.uuid,
      "announcementsChannel": announcementsChannel
    });
  }

  static final Map<Snowflake, GuildPreferences> _loadedPreferences = {};

  static Future<GuildPreferences> getForGuild(Snowflake guildId) async {
    if (_loadedPreferences.containsKey(guildId)) {
      return _loadedPreferences[guildId]!;
    }

    _loadedPreferences[guildId] = await loadFromDatabase(guildId);
    return _loadedPreferences[guildId]!;
  }

  static Future<GuildPreferences> loadFromDatabase(Snowflake guildId) async {
    GuildPreferences guildPreference;

    Row? row;
    try {
      row = Db.db!.select(
          "SELECT preferences FROM ${table.name} WHERE guildId = ?",
          [guildId.value]).firstOrNull;
    } catch (error) {
      row = null;
    }

    if (row == null) {
      guildPreference = GuildPreferences(guildId);
      Db.db!.execute(
          "INSERT INTO ${table.name} (guildId, preferences) VALUES (?, ?)",
          [guildId.value, guildPreference.toJson()]);
    } else {
      var preferences = jsonDecode(row['preferences']) as Map<String, dynamic>;
      guildPreference = GuildPreferences(guildId,
          premierTeamUuid: preferences["premierTeam"],
          announcementsChannel: preferences["announcementsChannel"]);
    }

    return guildPreference;
  }
}
