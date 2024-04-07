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
  KeywordAutoreact("alecks",
      ReactionBuilder(name: "alecks", id: Snowflake(1143687438045302864))),

  // Friends
  KeywordAutoreact("swit",
      ReactionBuilder(name: "sagelove", id: Snowflake(1226382840422207548))),
  KeywordAutoreact("lauten", ReactionBuilder(name: "🦑", id: null)),
  KeywordAutoreact("mh", ReactionBuilder(name: "🌽", id: null)),
  KeywordAutoreact("italian", ReactionBuilder(name: "🐧", id: null)),
  KeywordAutoreact("ben", ReactionBuilder(name: "🤓", id: null)),
  KeywordAutoreact("paige", ReactionBuilder(name: "🥛", id: null)),
  KeywordAutoreact("bloom", ReactionBuilder(name: "🪷", id: null)),
  KeywordAutoreact("glaze",
      ReactionBuilder(name: "glaze", id: Snowflake(1226388046203584552))),
  KeywordAutoreact(
      "kev", ReactionBuilder(name: "kev", id: Snowflake(1226386493774237738))),
  KeywordAutoreact("neonbot", ReactionBuilder(name: "💙", id: null)),
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
