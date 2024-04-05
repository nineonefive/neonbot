import 'package:neonbot/src/neonbot.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

final clear = ChatCommand("clear", "Clears the upcoming matches",
    (ChatContext context) async {
  var events = await context.guild!.scheduledEvents.list();

  if (events.isEmpty) {
    await context.respond(MessageBuilder(content: ":x: No events found"));
    return;
  }

  for (var event in events) {
    if (event.creatorId == NeonBot.instance.botUser.id) {
      await event.delete();
    }
  }

  await context.respond(MessageBuilder(
      content: ":white_check_mark: Cleared ${events.length} events"));
});

final events =
    ChatGroup("matches", "Manage the match events", children: [clear]);
