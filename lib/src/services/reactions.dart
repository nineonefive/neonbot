import 'package:nyxx/nyxx.dart';

import '../events.dart';

final milkTruckDiscord = Snowflake(1101930063819190425);

class AutoreactService {
  static late final AutoreactService _instance;

  static void init() {
    _instance = AutoreactService._();
  }

  factory AutoreactService() => _instance;

  final Map<String, Reaction> _index = {};
  final Logger logger = Logger("AutoreactService");

  AutoreactService._() {
    eventBus
        .on<MessageCreateEvent>()
        .where((event) => event.guildId == milkTruckDiscord)
        .listen(reactToMessage);

    _createIndex();
  }

  /// Applies each reaction to the message [event.message]
  Future<void> reactToMessage(MessageCreateEvent event) async {
    var reactions = event.message.content
        .split(" ")
        .map((word) => word.trim().toLowerCase())
        .map((word) => _index[word])
        .nonNulls
        .toSet(); // Remove duplicates

    for (var reaction in reactions) {
      await reaction.react(event.message);
    }
  }

  void _createIndex() {
    for (var reaction in Reactions.reactions) {
      _index[reaction.keyword] = reaction;
    }
  }
}

abstract class Reaction {
  final String keyword;

  Reaction(this.keyword);

  Future<void> react(Message message);

  @override
  int get hashCode => keyword.hashCode;

  @override
  bool operator ==(other) => other is Reaction && keyword == other.keyword;
}

class SingleReaction extends Reaction {
  final ReactionBuilder emoji;

  SingleReaction(super.keyword, this.emoji);

  @override
  Future<void> react(Message message) async {
    await message.react(emoji);
  }

  @override
  String toString() => "SingleReaction($keyword)";
}

class MultiReaction extends Reaction {
  final List<ReactionBuilder> emojis;

  MultiReaction(super.keyword, this.emojis);

  @override
  Future<void> react(Message message) async {
    for (var emoji in emojis) {
      await message.react(emoji);
    }
  }

  @override
  String toString() => "MultiReaction($keyword)";
}

class Reactions {
  static final List<Reaction> reactions = [
    SingleReaction("man",
        ReactionBuilder(name: "MAN", id: Snowflake(1213704607658807336))),
    SingleReaction("costco",
        ReactionBuilder(name: "costco", id: Snowflake(1167897307811954828))),
    SingleReaction("alecks",
        ReactionBuilder(name: "alecks", id: Snowflake(1143687438045302864))),

    // Friends
    SingleReaction("swit",
        ReactionBuilder(name: "sagelove", id: Snowflake(1226382840422207548))),
    SingleReaction("lauten", ReactionBuilder(name: "🦑", id: null)),
    SingleReaction("mh", ReactionBuilder(name: "🌽", id: null)),
    SingleReaction("italian", ReactionBuilder(name: "🐧", id: null)),
    SingleReaction("ben", ReactionBuilder(name: "🤓", id: null)),
    SingleReaction("paige", ReactionBuilder(name: "🥛", id: null)),
    SingleReaction("bloom", ReactionBuilder(name: "🪷", id: null)),
    SingleReaction("glaze",
        ReactionBuilder(name: "glaze", id: Snowflake(1226388046203584552))),
    SingleReaction("kev",
        ReactionBuilder(name: "kev", id: Snowflake(1226386493774237738))),
    SingleReaction("neonbot", ReactionBuilder(name: "💙", id: null)),
  ];
}
