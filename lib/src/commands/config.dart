import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import '../embeds.dart';
import '../events.dart';
import '../events/interaction_create.dart';
import '../services/preferences.dart';
import '../services/tracker.dart';
import '../util.dart';

final _configEditCommand = ChatCommand(
    'edit', "Edits the configuration of the bot", (ChatContext context,
        [@Description("The announcements channel")
        Channel? announcementChannelId,
        @Description("The match voice call channel")
        Channel? voiceChannelId]) async {
  final guild = context.guild!;

  // If the guild is not loaded, we'll fetch it from database and tell the user
  // to wait before retrying.
  if (!GuildSettings.service.isGuildLoaded(guild.id)) {
    var message = await context.respond(MessageBuilder(
        content:
            ":hourglass: Loading preferences.. Please wait before using command again"));
    scheduleMicrotask(() async {
      await GuildSettings.service.getForGuild(guild.id);
      message.edit(MessageUpdateBuilder(content: ":white_check_mark: Done"));
    });

    return;
  }

  // Load preferences and all the channels
  var gp = await GuildSettings.service.getForGuild(context.guild!.id);

  // Otherwise construct the configuration modal
  var components = [
    // Selection modal for the announcement channel
    ActionRowBuilder(components: [
      SelectMenuBuilder.channelSelect(
          customId: "announcementChannel",
          placeholder: "Announcements channel",
          minValues: 1,
          maxValues: 1,
          defaultValues: switch (gp.announcementsChannel) {
            null => null,
            _ => [DefaultValue.channel(id: gp.announcementsChannel!)]
          })
    ]),
    // Selection modal for the voice channel
    ActionRowBuilder(components: [
      SelectMenuBuilder.channelSelect(
          customId: "voiceChannel",
          placeholder: "Match voice channel",
          minValues: 1,
          maxValues: 1,
          defaultValues: switch (gp.voiceChannel) {
            null => null,
            _ => [DefaultValue.channel(id: gp.voiceChannel!)]
          })
    ]),
    ActionRowBuilder(components: [
      ButtonBuilder(
        customId: "submit",
        style: ButtonStyle.secondary,
        label: "Save",
      )
    ])
  ];

  // ignore: prefer_interpolation_to_compose_strings
  var content = "Update the server config:\n" +
      [
        "- **Announcements channel**: Match signups will be posted here",
        "- **Match voice call channel**: Events will be hosted in this channel"
      ].join("\n");

  var messageBuilder = MessageBuilder(content: content, components: components);
  var message = await context.respond(messageBuilder);
  eventBus.fire(InteractionComponentCreatedEvent('guild-preferences', message));
});

final _configTeam = ChatCommand('team', "Sets the current premier team",
    (ChatContext context,
        @Description("The team's riot id") String riotId) async {
  String message;
  try {
    var team = await TrackerApi.service.searchByRiotId(riotId);

    var preferences =
        await GuildSettings.service.getForGuild(context.guild!.id);
    preferences.premierTeamId = team.id;

    message = "Server premier team set to `${team.riotId}`";

    // Now we perform the full update on the team, which will take longer
    scheduleMicrotask(() async {
      var updatedTeam = await TrackerApi.service.searchByUuid(team.id);
      preferences.premierTeamId = updatedTeam.id;
      preferences.persistToDb();
    });
  } catch (error) {
    message = switch (error) {
      PremierTeamDoesntExistException(team: var team) =>
        "Team `$team` not found on tracker.gg",
      InvalidRiotIdException(id: var riotId) =>
        "Riot id `$riotId` is improperly formatted",
      TrackerApiException() => "Error connecting to tracker.gg",
      _ => "Unknown exception occurred"
    };
  }

  if (context case InteractiveContext context) {
    context.respond(MessageBuilder(content: message));
  }
});

final _configShow = ChatCommand("show", "Shows the current config",
    (ChatContext context) async {
  var gp = await GuildSettings.service.getForGuild(context.guild!.id);
  context.respond(MessageBuilder(embeds: [await gp.asEmbed]));
}, aliases: ["view"]);

/// Command for editing the bot's guild configuration. This cannot include the
/// premier team since discord doesn't allow text input in the modal.
final config = ChatGroup("config", "View or edit the neonbot config",
    children: [_configEditCommand, _configTeam, _configShow],
    checks: [UserHasRoleCheck("neonbot admin")]);
