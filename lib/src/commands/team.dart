import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import '../embeds.dart';
import '../services/preferences.dart';

final team = ChatCommand('team', "Gets the current premier team details",
    (ChatContext context) async {
  var preferences = await GuildSettings.service.getForGuild(context.guild!.id);
  var teamPromise = preferences.premierTeam;
  var message = await context.respond(
      MessageBuilder(content: ":hourglass: Loading data from tracker.."));

  teamPromise.then((team) {
    if (team != null) {
      message.edit(MessageUpdateBuilder(content: "", embeds: [team.asEmbed]));
    } else {
      message.edit(MessageUpdateBuilder(content: ":x: No team set"));
    }
  });
});
