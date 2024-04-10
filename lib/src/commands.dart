import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

export 'commands/config.dart' show config;
export 'commands/events.dart' show events;
export 'commands/restart.dart' show restart;
export 'commands/schedule.dart' show schedule;
export 'commands/team.dart' show team;

Future<String> Function(MessageCreateEvent) slashCommand() {
  return (event) async {
    return "/";
  };
}

Future<void> errorHandler(error) async {
  if (error is CheckFailedException) {
    error.context.respond(
        MessageBuilder(content: ":x: Sorry, you can't use that command!"));
  }
}
