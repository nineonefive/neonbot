import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import '../embeds/schedule.dart';
import '../services/guilds.dart';
import '../services/tracker/tracker.dart';

final schedule = ChatCommand(
    'schedule',
    "View the upcoming schedule",
    id('schedule', (ChatContext context) async {
      var message =
          await context.respond(MessageBuilder(content: ":hourglass:"));
      var gp = await GuildService().getPreferences(context.guild!.id);
      if (!gp.hasPremierRegion) {
        message
            .edit(MessageUpdateBuilder(content: ":x: No region or team set"));
        return;
      }

      var schedule = await TrackerApi().getSchedule(gp.premierRegion);

      await message.edit(MessageUpdateBuilder(
          content: "", embeds: [schedule.asEmbed(gp.premierRegion)]));
    }));
