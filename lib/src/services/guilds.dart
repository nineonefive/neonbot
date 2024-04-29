import 'dart:convert';

import 'package:nyxx/nyxx.dart' hide Cache;
import 'package:sqlite3/common.dart';

import '../cache.dart';
import '../models/guild_preferences.dart';
import '../neonbot.dart';
import 'db.dart';

final table = Tables.guildPreferences;

class GuildService {
  static final _instance = GuildService._();

  factory GuildService() {
    return _instance;
  }

  late final Cache<Snowflake, GuildPreferences> _cache;

  GuildService._() {
    _cache = Cache(
      retrieve: (guildId) async {
        var gp = await _loadPreferences(guildId);
        return gp ?? await _defaultPreferences(guildId);
      },
      onEvict: (guildId, gp) async {
        savePreferences(gp);
      },
      maxSize: 100,
    );

    // Saves all preferences to the database since evict = true
    NeonBot().onShutdown(_cache.clear, priority: Priority.low);
  }

  /// Checks if the settings for guild [guildId] have been loaded
  bool isGuildLoaded(Snowflake guildId) {
    return _cache.containsKey(guildId);
  }

  /// Loads the settings for guild [guildId], using the cache if possible
  Future<GuildPreferences> getPreferences(Snowflake guildId) async {
    var result = await _cache.get(guildId);
    return result!;
  }

  /// Reloads the preferences from the database into the cache. Useful
  /// for trying to undo transactions
  Future<GuildPreferences> reloadPreferences(Snowflake guildId) async {
    _cache.remove(guildId);
    return (await _loadPreferences(guildId))!;
  }

  /// Saves the guild settings [gp] to the database
  Future<void> savePreferences(GuildPreferences gp) async {
    DatabaseService.service!.execute(
        "UPDATE ${table.name} SET preferences = ? WHERE guildId = ?",
        [jsonEncode(gp.toJson()), gp.guildId.value]);
  }

  /// Loads the settings for guild [guildId] from the database, returning null
  /// if not found
  Future<GuildPreferences?> _loadPreferences(Snowflake guildId) async {
    Row? row;
    row = DatabaseService.service!.select(
        "SELECT preferences FROM ${table.name} WHERE guildId = ?",
        [guildId.value]).firstOrNull;

    if (row == null) {
      return null;
    }

    return GuildPreferences.fromJson(jsonDecode(row['preferences']));
  }

  /// Creates the new default settings for guild [guildId] and
  /// saves to database
  Future<GuildPreferences> _defaultPreferences(Snowflake guildId) async {
    var gp = GuildPreferences(guildId);
    DatabaseService.service!.execute(
        "INSERT INTO ${table.name} (guildId, preferences) VALUES (?, ?)",
        [guildId.value, jsonEncode(gp.toJson())]);

    return gp;
  }

  /// Returns the full list of guilds we have saved
  List<Snowflake> getAllKnownGuilds() {
    var rows =
        DatabaseService.service!.select("SELECT guildId FROM ${table.name}");
    return rows.map((row) => Snowflake(row['guildId'])).toList();
  }
}
