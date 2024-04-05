import 'package:nyxx/nyxx.dart';
import 'package:sqlite3/common.dart';

import '../embeds.dart';
import '../events.dart';
import '../events/interaction_create.dart';
import '../models/guild_preferences.dart';
import 'db.dart';

class GuildSettings {
  static final service = GuildSettings._();
  final Map<Snowflake, InteractionComponentCreatedEvent> _interactionEvents =
      {};
  final Map<Snowflake, GuildPreferences> _loadedPreferences = {};

  GuildSettings._() {
    // Listen to the /config modal
    eventBus
        .onInteractionComponentCreated("guild-preferences")
        .listen(registerComponentInteraction);

    // When we join a guild, load its settings
    eventBus.on<GuildCreateEvent>().listen((event) async {
      _loadedPreferences[event.guild.id] =
          await loadFromDatabase(event.guild.id);
    });

    // Finally, actually listen to interactions
    eventBus.on<InteractionCreateEvent>().listen(handleInteraction);
  }

  /// Checks if the settings for guild [guildId] have been loaded
  bool isGuildLoaded(Snowflake guildId) {
    return _loadedPreferences.containsKey(guildId);
  }

  /// Loads the settings for guild [guildId], using the cache if possible
  Future<GuildPreferences> getForGuild(Snowflake guildId) async {
    if (_loadedPreferences.containsKey(guildId)) {
      return _loadedPreferences[guildId]!;
    }

    return await refresh(guildId);
  }

  Future<GuildPreferences> refresh(Snowflake guildId) async {
    _loadedPreferences[guildId] = await loadFromDatabase(guildId);
    return _loadedPreferences[guildId]!;
  }

  Future<GuildPreferences> loadFromDatabase(Snowflake guildId) async {
    GuildPreferences guildPreference;

    Row? row;
    try {
      row = DatabaseService.service!.select(
          "SELECT preferences FROM ${table.name} WHERE guildId = ?",
          [guildId.value]).firstOrNull;
    } catch (error) {
      row = null;
    }

    if (row == null) {
      guildPreference = GuildPreferences(guildId);
      DatabaseService.service!.execute(
          "INSERT INTO ${table.name} (guildId, preferences) VALUES (?, ?)",
          [guildId.value, guildPreference.toJson()]);
    } else {
      guildPreference = GuildPreferences.fromJson(row['preferences']);
    }

    return guildPreference;
  }

  List<Snowflake> getAllKnownGuilds() {
    var rows =
        DatabaseService.service!.select("SELECT guildId FROM ${table.name}");
    return rows.map((row) => Snowflake(row['guildId'])).toList();
  }

  void registerComponentInteraction(InteractionComponentCreatedEvent event) {
    _interactionEvents[event.message.id] = event;
    logger.fine("Added interaction: ${event.message.id}");

    // Expire the prompt after 2 minutes
    Future.delayed(Duration(minutes: 2),
        () => expireInteraction(event.message.id, ":x: Expired"));
  }

  void handleInteraction(InteractionCreateEvent<dynamic> event) async {
    var interaction = event.interaction;
    if (interaction is MessageComponentInteraction) {
      var message = interaction.message;
      if (message == null || !_interactionEvents.containsKey(message.id)) {
        return;
      }

      var gp = await getForGuild(interaction.guildId!);
      var data = int.parse(interaction.data.values?.firstOrNull ?? "0");

      switch (interaction.data.customId) {
        // When the user submits, we persist the changes and remove the form.
        case "submit":
          _interactionEvents.remove(message.id);
          // Avoid 10062 error
          await interaction.respond(
              MessageUpdateBuilder(content: ":hourglass:", components: []),
              updateMessage: true);

          gp.persistToDb();
          await interaction.updateOriginalResponse(MessageUpdateBuilder(
              content: "", embeds: [await gp.asEmbed], components: []));

        // When the user cancels, we should refresh the preferences from the database
        case "cancel":
          expireInteraction(message.id, ":x: Cancelled by user");

        // If the user edits other settings, we simply acknowledge them
        case "announcementChannel":
          gp.announcementsChannel = Snowflake(data);
          await interaction.acknowledge(updateMessage: true);
        case "voiceChannel":
          gp.voiceChannel = Snowflake(data);
          await interaction.acknowledge(updateMessage: true);
        case "roleMention":
          gp.tagForSignupRole = Snowflake(data);
          await interaction.acknowledge(updateMessage: true);
      }
    }
  }

  void expireInteraction(Snowflake messageId, String reason) async {
    if (_interactionEvents.containsKey(messageId)) {
      var event = _interactionEvents.remove(messageId)!;
      event.message.edit(MessageUpdateBuilder(content: reason, components: []));

      // Refresh the preferences from db
      refresh(event.guildId);
    }
  }
}
