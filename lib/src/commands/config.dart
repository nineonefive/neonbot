import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import '../embeds.dart';
import '../events.dart';
import '../events/interaction_create.dart';
import '../forms/config.dart';
import '../services/preferences.dart';
import '../services/tracker.dart';
import '../util.dart';

final _configEditCommand = ChatCommand(
    'edit',
    "Edits the configuration of the bot",
    id('config-edit', (ChatContext context) async {
      final guild = context.guild!;

      // If the guild is not loaded, we'll fetch it from database and tell the user
      // to wait before retrying.
      if (!GuildSettings.service.isGuildLoaded(guild.id)) {
        var message =
            await context.respond(MessageBuilder(content: ":hourglass:"));

        // Schedule an update in the background
        Future(() async {
          await GuildSettings.service.getForGuild(guild.id);
          message
              .edit(MessageUpdateBuilder(content: ":white_check_mark: Ready"));
        });

        return;
      }

      var form = await createConfigForm(guild.id);
      var message = await context.respond(form);
      eventBus.fire(InteractionComponentCreatedEvent(
          'guild-preferences', message, context.guild!.id));
    }));

final _configTeam = ChatCommand(
    'team',
    "Sets the current premier team",
    id('config-team', (ChatContext context,
        @Description("The team's riot id") String riotId) async {
      String message;
      try {
        var team = await TrackerApi.service.searchByRiotId(riotId);

        var preferences =
            await GuildSettings.service.getForGuild(context.guild!.id);
        preferences.partialTeam = team;

        message = "Server premier team set to `${team.name}`";

        // Sync to database and pull the team details into tracker service
        Future(() async {
          preferences.persistToDb();
          await TrackerApi.service.searchByUuid(team.id);
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
    }));

final _configShow = ChatCommand(
    "show",
    "Shows the current config",
    id('config-show', (ChatContext context) async {
      var gp = await GuildSettings.service.getForGuild(context.guild!.id);
      context.respond(MessageBuilder(embeds: [await gp.asEmbed]));
    }),
    aliases: ["view"]);

/// Command for editing the bot's guild configuration. This cannot include the
/// premier team since discord doesn't allow text input in the modal.
final config = ChatGroup("config", "View or edit the neonbot config",
    children: [_configEditCommand, _configTeam, _configShow],
    checks: [UserHasRoleCheck("neonbot admin")]);
