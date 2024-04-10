import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

export 'commands/config.dart' show config;
export 'commands/team.dart' show team;
export 'commands/schedule.dart' show schedule;
export 'commands/events.dart' show events;

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
