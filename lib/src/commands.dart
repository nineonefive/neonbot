import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

export 'commands/config.dart' show config;
export 'commands/team.dart' show team;
export 'commands/schedule.dart' show schedule;
export 'commands/events.dart' show events;

final RegExp _mentionPattern = RegExp(r'^<@!?([0-9]{15,20})>');
Future<String> Function(MessageCreateEvent) slashCommand() {
  return (event) async {
    RegExpMatch? match = _mentionPattern.firstMatch(event.message.content);

    if (match != null) {
      if (int.parse(match.group(1)!) ==
          (await event.gateway.client.users.fetchCurrentUser()).id.value) {
        return match.group(0)!;
      }
    }

    return "/";
  };
}

Future<void> errorHandler(error) async {
  if (error is CheckFailedException) {
    error.context.respond(
        MessageBuilder(content: ":x: Sorry, you can't use that command!"));
  }
}
