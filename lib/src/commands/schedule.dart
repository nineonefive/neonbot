import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import '../embeds/schedule.dart';
import '../services/preferences.dart';
import '../services/tracker.dart';

final schedule = ChatCommand(
    'schedule',
    "View the upcoming schedule",
    id('schedule', (ChatContext context) async {
      var message =
          await context.respond(MessageBuilder(content: ":hourglass:"));
      var gp = await GuildSettings.service.getForGuild(context.guild!.id);
      if (!gp.hasPremierTeam) {
        message.edit(MessageUpdateBuilder(content: ":x: No team set"));
        return;
      }

      var team = await gp.premierTeam;
      var schedule = await TrackerApi.service.getSchedule(team.zone);

      await message.edit(MessageUpdateBuilder(
          content: "", embeds: [schedule.asEmbed(team.zone, team.zoneName)]));
    }));
