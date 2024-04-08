import 'package:nyxx/nyxx.dart';

import '../events.dart';

final milkTruckDiscord = Snowflake(1101930063819190425);

class AutoreactService {
  static late final AutoreactService instance;

  final Map<String, KeywordAutoreact> index = {};
  final Logger logger = Logger("AutoreactService");

  static void init() {
    instance = AutoreactService._();
  }

  AutoreactService._() {
    eventBus
        .on<MessageCreateEvent>()
        .where((event) => event.guildId == milkTruckDiscord)
        .listen(reactToMessage);

    _createReactions();

    logger.fine("Autoreactions: ${index}");
  }

  Future<void> reactToMessage(MessageCreateEvent event) async {
    var reactions = event.message.content
        .split(" ")
        .map((word) => word.trim().toLowerCase())
        .map((word) => index[word])
        .nonNulls
        .toSet(); // Remove duplicates

    for (var reaction in reactions) {
      await event.message.react(reaction.emoji);
    }
  }

  void _createReactions() {
    var reactions = [
      KeywordAutoreact("man",
          ReactionBuilder(name: "MAN", id: Snowflake(1213704607658807336))),
      KeywordAutoreact("costco",
          ReactionBuilder(name: "costco", id: Snowflake(1167897307811954828))),
      KeywordAutoreact("alecks",
          ReactionBuilder(name: "alecks", id: Snowflake(1143687438045302864))),

      // Friends
      KeywordAutoreact(
          "swit",
          ReactionBuilder(
              name: "sagelove", id: Snowflake(1226382840422207548))),
      KeywordAutoreact("lauten", ReactionBuilder(name: "🦑", id: null)),
      KeywordAutoreact("mh", ReactionBuilder(name: "🌽", id: null)),
      KeywordAutoreact("italian", ReactionBuilder(name: "🐧", id: null)),
      KeywordAutoreact("ben", ReactionBuilder(name: "🤓", id: null)),
      KeywordAutoreact("paige", ReactionBuilder(name: "🥛", id: null)),
      KeywordAutoreact("bloom", ReactionBuilder(name: "🪷", id: null)),
      KeywordAutoreact("glaze",
          ReactionBuilder(name: "glaze", id: Snowflake(1226388046203584552))),
      KeywordAutoreact("kev",
          ReactionBuilder(name: "kev", id: Snowflake(1226386493774237738))),
      KeywordAutoreact("neonbot", ReactionBuilder(name: "💙", id: null)),
    ];

    for (var reaction in reactions) {
      index[reaction.keyword] = reaction;
    }
  }
}

class KeywordAutoreact {
  final String keyword;
  final ReactionBuilder emoji;

  KeywordAutoreact(this.keyword, this.emoji);

  @override
  int get hashCode => emoji.hashCode;

  @override
  bool operator ==(other) => other is KeywordAutoreact && emoji == other.emoji;

  @override
  String toString() => "KeywordAutoreact($keyword)";
}
