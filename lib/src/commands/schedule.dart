import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import '../embeds/schedule.dart';
import '../services/preferences.dart';
import '../services/tracker.dart';

final schedule = ChatCommand('schedule', "View the upcoming schedule",
    (ChatContext context) async {
  var message = await context.respond(
      MessageBuilder(content: ":hourglass: Loading data from tracker.."));
  var gp = await GuildSettings.service.getForGuild(context.guild!.id);
  var team = await gp.premierTeam;
  if (team == null) {
    message.edit(MessageUpdateBuilder(content: ":x: No team set"));
    return;
  }

  var schedule = await TrackerApi.service.getSchedule(team.zone);

  await message.edit(MessageUpdateBuilder(
      content: "", embeds: [schedule.asEmbed(team.zone, team.zoneName)]));
});
