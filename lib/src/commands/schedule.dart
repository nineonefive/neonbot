import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import '../models/match_schedule.dart';
import '../services/preferences.dart';
import '../services/tracker.dart';
import '../style.dart';
import '../util.dart';

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
  var scheduleString = "";
  var upcomingMatches =
      schedule.matches.where((m) => m.time.isAfter(DateTime.now()));

  String? lastMap;
  for (var match in upcomingMatches) {
    if (match.map == lastMap && match.matchType != MatchType.playoffs) {
      scheduleString +=
          "- ${match.matchType.name} ${match.time.toDiscord(team.zone)}\n";
    } else {
      lastMap = match.map;
      // Show map header, then print match
      var header = (match.matchType == MatchType.playoffs)
          ? "${mapEmojis["playoffs"]}  Playoffs"
          : "${mapEmojis[match.map]}  ${match.map}";
      scheduleString += "## $header\n";
      scheduleString +=
          "- ${match.matchType.name} ${match.time.toDiscord(team.zone)}\n";
    }
  }

  await message.edit(MessageUpdateBuilder(content: "", embeds: [
    EmbedBuilder()
      ..color = Colors.primary
      ..footer = EmbedFooterBuilder(text: "Times shown in your local time")
      ..title = "${team.zoneName} Schedule"
      ..description = scheduleString
  ]));
});
