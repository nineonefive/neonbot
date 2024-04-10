import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import '../embeds.dart';
import '../services/guilds.dart';

final team = ChatCommand(
    'team',
    "Gets the current premier team details",
    id('team', (ChatContext context) async {
      var gp = await GuildService().getPreferences(context.guild!.id);

      if (!gp.hasPremierTeam) {
        await context.respond(MessageBuilder(content: ":x: No team set"));
        return;
      }

      var message =
          await context.respond(MessageBuilder(content: ":hourglass:"));
      var team = await gp.premierTeam;
      message.edit(MessageUpdateBuilder(content: "", embeds: [team.asEmbed]));
    }));
