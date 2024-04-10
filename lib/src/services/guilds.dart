import 'dart:convert';

import 'package:nyxx/nyxx.dart' hide Cache;
import 'package:sqlite3/common.dart';

import '../cache.dart';
import '../embeds.dart';
import '../events.dart';
import '../events/interaction_create.dart';
import '../models/guild_preferences.dart';
import 'db.dart';

final table = Tables.GuildPreferences;

class GuildService {
  static final _instance = GuildService._();

  factory GuildService() {
    return _instance;
  }

  final Map<Snowflake, InteractionComponentCreatedEvent> _interactionEvents =
      {};
  late final Cache<Snowflake, GuildPreferences> _cache;

  GuildService._() {
    _cache = Cache(
        retrieve: (guildId) async {
          var gp = await _load(guildId);
          return gp ?? await _createNew(guildId);
        },
        onEvict: (guildId, gp) async {
          save(gp);
        },
        maxSize: 100);
    _registerEvents();
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
    return (await _load(guildId))!;
  }

  /// Saves the guild settings [gp] to the database
  Future<void> save(GuildPreferences gp) async {
    DatabaseService.service!.execute(
        "UPDATE ${table.name} SET preferences = ? WHERE guildId = ?",
        [jsonEncode(gp.toJson()), gp.guildId.value]);
  }

  /// Loads the settings for guild [guildId] from the database, returning null
  /// if not found
  Future<GuildPreferences?> _load(Snowflake guildId) async {
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
  Future<GuildPreferences> _createNew(Snowflake guildId) async {
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

  void _registerComponentInteraction(InteractionComponentCreatedEvent event) {
    _interactionEvents[event.message.id] = event;
    logger.fine("Added interaction: ${event.message.id}");

    // Expire the prompt after 2 minutes
    Future.delayed(Duration(minutes: 2),
        () => _expireInteraction(event.message.id, ":x: Expired"));
  }

  void _handleInteraction(InteractionCreateEvent<dynamic> event) async {
    var interaction = event.interaction;
    if (interaction is MessageComponentInteraction) {
      var message = interaction.message;
      if (message == null || !_interactionEvents.containsKey(message.id)) {
        return;
      }

      var gp = await getPreferences(interaction.guildId!);
      var data = int.parse(interaction.data.values?.firstOrNull ?? "0");

      switch (interaction.data.customId) {
        // When the user submits, we persist the changes and remove the form.
        case "submit":
          _interactionEvents.remove(message.id);
          // Avoid 10062 error
          await interaction.respond(
              MessageUpdateBuilder(content: ":hourglass:", components: []),
              updateMessage: true);

          await GuildService().save(gp);
          await interaction.updateOriginalResponse(MessageUpdateBuilder(
              content: "", embeds: [await gp.asEmbed], components: []));

        // When the user cancels, we should refresh the preferences from the database
        case "cancel":
          _expireInteraction(message.id, ":x: Cancelled by user");

        // If the user edits other settings, we simply acknowledge them
        case "announcementChannel":
          gp.announcementsChannel = Snowflake(data);
          await interaction.acknowledge(updateMessage: true);
        case "voiceChannel":
          gp.voiceChannel = Snowflake(data);
          await interaction.acknowledge(updateMessage: true);
        case "signupRole":
          gp.signupRole = Snowflake(data);
          await interaction.acknowledge(updateMessage: true);
      }
    }
  }

  void _expireInteraction(Snowflake messageId, String reason) async {
    if (_interactionEvents.containsKey(messageId)) {
      var event = _interactionEvents.remove(messageId)!;
      event.message.edit(MessageUpdateBuilder(content: reason, components: []));

      // Refresh the preferences from db
      reloadPreferences(event.guildId);
    }
  }

  void _registerEvents() {
    // Listen to the /config modal being created
    eventBus
        .onInteractionComponentCreated("guild-preferences")
        .listen(_registerComponentInteraction);

    // Listen to interactions involving the /config modal
    eventBus.on<InteractionCreateEvent>().listen(_handleInteraction);
  }
}
