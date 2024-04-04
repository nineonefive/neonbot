import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import 'guild_preferences.dart';
import 'premier_team.dart';

final RegExp _mentionPattern = RegExp(r'^<@!?([0-9]{15,20})>');
Future<String> Function(MessageCreateEvent) slashCommand() {
  return (event) async {
    RegExpMatch? match = _mentionPattern.firstMatch(event.message.content);

    if (match != null) {
      if (int.parse(match.group(1)!) ==
          (await event.gateway.client.users.fetchCurrentUser()).id.value) {
        return match.group(0)!;
      }
    }

    return "/";
  };
}

class UserHasRoleCheck extends Check {
  UserHasRoleCheck(String roleName)
      : super((context) async {
          // Get the roles of the user and check if any match "neonbot admin"
          var partialRoles = context.member?.roles ?? [];
          var futures = partialRoles.map((pr) async {
            var role = await pr.manager.fetch(pr.id);
            return role.name == roleName;
          });

          // Map the List<Future<bool>> to a Future<bool> with the equivalent
          // of an any() operation
          var future = Future.wait(futures).then((results) =>
              results.isNotEmpty && results.reduce((x, y) => x | y));
          return await future;
        }, name: "has-role $roleName");
}

final _setTeam = ChatCommand('set_team', "Sets the premier team for the server",
    (ChatContext context,
        [@Description("The team's full riot id") String? riotId]) async {
  String message;
  try {
    var riotId = await (context.arguments.first ?? "");
    var team = await TrackerApi.searchByRiotId(riotId);

    var preferences = await GuildPreferences.getForGuild(context.guild!.id);
    preferences.premierTeam = team;

    message = "Server premier team set to `${team.riotId}`";

    // Now we perform the full update on the team, which will take longer
    scheduleMicrotask(() async {
      var updatedTeam = await TrackerApi.searchByUuid(team.uuid);
      preferences.premierTeam = updatedTeam;
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
}, checks: [UserHasRoleCheck("neonbot admin")]);

final _getTeam = ChatCommand('team', "Gets the current premier team details",
    (ChatContext context) async {
  var preferences = await GuildPreferences.getForGuild(context.guild!.id);
  var team = preferences.premierTeam;

  if (team != null) {
    context.respond(MessageBuilder(embeds: [createTeamEmbed(team)]));
  } else {
    // If this is the first time a member of the guild has used a command since the bot
    // was started, the preferences haven't been loaded. It's possible that the guild does
    // have a team set, so we check if one is being loaded. If so, we'll show a temporary message
    // then update it once ready.
    if (preferences.teamPromise != null) {
      var message = await context.respond(
          MessageBuilder(content: ":hourglass: Loading data from tracker.."));

      preferences.teamPromise!.then((value) {
        message.edit(MessageUpdateBuilder(
            content: "", embeds: [createTeamEmbed(value)]));
      });
    } else {
      context.respond(MessageBuilder(content: ":x: No team set"));
    }
  }
});

List<CommandRegisterable<CommandContext>> getAllCommands() {
  // Todo: fill out all commands
  return [_setTeam, _getTeam];
}

EmbedBuilder createTeamEmbed(PremierTeam team) {
  var description = [
    "**Rank**: \\#${team.rank}",
    "**Division**: ${team.division}",
    "**Season points**: ${team.leagueScore}",
  ].join("\n");

  var footer = EmbedFooterBuilder(
      text: "${team.riotId} • ${team.zoneName} • tracker.gg");

  var embed = EmbedBuilder(
      color: DiscordColor.parseHexString("#03fccf"),
      title: team.riotId,
      url: Uri.https('tracker.gg', '/valorant/premier/teams/${team.uuid}'),
      description: description,
      footer: footer);

  return embed;
}
