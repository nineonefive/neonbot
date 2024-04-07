import 'package:nyxx/nyxx.dart';

import '../events.dart';

final milkTruckDiscord = Snowflake(1101930063819190425);
final keywordReactions = [
  KeywordAutoreact(
      "man", ReactionBuilder(name: "MAN", id: Snowflake(1213704607658807336)),
      milkTruckOnly: true),
  KeywordAutoreact("costco",
      ReactionBuilder(name: "costco", id: Snowflake(1167897307811954828)),
      milkTruckOnly: true),
  KeywordAutoreact("corn", ReactionBuilder(name: "🌽", id: Snowflake.zero)),
  KeywordAutoreact("neonbot", ReactionBuilder(name: "💙", id: Snowflake.zero)),
  KeywordAutoreact("lauten", ReactionBuilder(name: "🦑", id: Snowflake.zero)),
  KeywordAutoreact("alecks",
      ReactionBuilder(name: "alecks", id: Snowflake(1143687438045302864))),
];

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

    for (var reaction in keywordReactions) {
      if (words.contains(reaction.keyword)) {
        if (reaction.milkTruckOnly && event.guildId != milkTruckDiscord) {
          continue;
        }

        await event.message.react(reaction.emoji);
      }
    }
  }
}

class KeywordAutoreact {
  final String keyword;
  final ReactionBuilder emoji;
  bool milkTruckOnly;

  KeywordAutoreact(this.keyword, this.emoji, {this.milkTruckOnly = false});
}
