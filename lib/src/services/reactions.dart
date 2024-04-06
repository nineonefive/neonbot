import 'package:nyxx/nyxx.dart';

import '../events.dart';

final manEmoji =
    ReactionBuilder(name: "MAN", id: Snowflake(1213704607658807336));
final milkTruckDiscord = Snowflake(110193006381919042);

class AutoreactService {
  static late final AutoreactService instance;

  final Logger logger = Logger("AutoreactService");

  static void init() {
    instance = AutoreactService._();
  }

  AutoreactService._() {
    eventBus.on<MessageCreateEvent>().listen(processMessage);
  }

  Future<void> processMessage(MessageCreateEvent event) async {
    var guildId = event.guildId;
    if (guildId == null) return;

    var words = event.message.content
        .split(" ")
        .map((word) => word.trim().toLowerCase());
    var shouldReact = words.any((word) => word == "man");

    logger.fine(
        "content: ${event.message.content}, react: $shouldReact, words: $words");

    if (shouldReact) {
      logger.fine("Received message with man in it");
      var isMilkTruckDiscord = guildId == milkTruckDiscord;

      if (isMilkTruckDiscord) {
        logger.fine("Posting man reaction");
        await event.message.react(manEmoji);
      }
    }
  }
}
