import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import '../neonbot.dart';

final devTeam = {
  Snowflake(200299141438504960) // 915
};

final restart = ChatCommand(
  'restart',
  "Restarts the bot",
  id('restart', (ChatContext context) async {
    await context.respond(MessageBuilder(content: ":hourglass: Restarting..."));
    NeonBot().shutdown();
  }),
  checks: [UserCheck.anyId(devTeam)],
);
