import 'package:nyxx/nyxx.dart';
import 'package:sqlite3/common.dart';

import '../embeds.dart';
import '../events.dart';
import '../events/interaction_create.dart';
import '../guild_preferences.dart';
import 'db.dart';

class GuildSettings {
  static final service = GuildSettings._();
  final _interactionMessages = Map<Snowflake, Message>();
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

  void loadAllPreferences(NyxxGateway client) async {
    // First pull all known guilds from the database
    Set<Snowflake> knownIds = Set.from(getAllKnownGuilds());

    // Fetch them into the client through discord
    for (var guildId in knownIds) {
      await client.guilds.get(guildId);
    }
    Set<Snowflake> actualIds = Set.from(client.guilds.cache.keys);

    for (var guildId in actualIds) {
      await getForGuild(guildId);
      logger.fine("Loaded preferences for $guildId");
    }
    logger.info("Loaded ${actualIds.length} guild(s)");

    // Finally, we may have some guilds that are in the database that the bot
    // is no longer in. We can delete them
    var toDelete = knownIds.difference(actualIds);
    if (toDelete.isNotEmpty) {
      logger.fine("Cleaning up ${toDelete.length} guilds");
      var stmt = DatabaseService.service!
          .prepare("DELETE FROM ${table.name} WHERE guildId = ?");
      for (var guildId in toDelete) {
        stmt.execute([guildId.value]);
      }
    }
  }

  void registerComponentInteraction(InteractionComponentCreatedEvent event) {
    _interactionMessages[event.message.id] = event.message;
    logger.fine("Added interaction: ${event.message.id}");

    // Expire the prompt after 1 minute
    Future.delayed(
        Duration(minutes: 1), () => expireInteraction(event.message.id));
  }

  void handleInteraction(InteractionCreateEvent<dynamic> event) async {
    var interaction = event.interaction;
    if (interaction is MessageComponentInteraction) {
      var message = interaction.message;
      if (message == null || !_interactionMessages.containsKey(message.id)) {
        return;
      }

      var gp = await getForGuild(interaction.guildId!);
      var data = interaction.data;

      switch (data.customId) {
        // When the user submits, we persist the changes and remove the form.
        case "submit":
          _interactionMessages.remove(message.id);
          // Avoid 10062 error
          await interaction.respond(
              MessageUpdateBuilder(
                  content: ":hourglass: Saving...", components: []),
              updateMessage: true);

          await interaction.updateOriginalResponse(MessageUpdateBuilder(
              content: "", embeds: [await gp.asEmbed], components: []));
          gp.persistToDb();

        // If the user edits other settings, we simply acknowledge them
        case "announcementChannel":
          Snowflake? channelId;
          if (data.values != null && data.values!.isNotEmpty) {
            channelId = Snowflake(int.parse(data.values!.first));
          }
          gp.announcementsChannel = channelId;
          await interaction.acknowledge(updateMessage: true);
        case "voiceChannel":
          Snowflake? channelId;
          if (data.values != null && data.values!.isNotEmpty) {
            channelId = Snowflake(int.parse(data.values!.first));
          }
          gp.voiceChannel = channelId;
          await interaction.acknowledge(updateMessage: true);
      }
    }
  }

  void expireInteraction(Snowflake messageId) async {
    if (_interactionMessages.containsKey(messageId)) {
      var message = _interactionMessages.remove(messageId);
      message!
          .edit(MessageUpdateBuilder(content: ":x: Expired", components: []));
    }
  }
}
