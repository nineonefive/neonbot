import 'package:nyxx/nyxx.dart';

import '../events.dart';
import '../style.dart';

final milkTruckDiscord = Snowflake(1101930063819190425);

class AutoreactService {
  static late final AutoreactService _instance;
  static final splitPattern = RegExp(r"\s+");

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
        .split(splitPattern)
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
    SingleReaction("man", Emojis.man),
    SingleReaction("costco", Emojis.costco),
    SingleReaction("alecks", Emojis.alecks),

    // Friends
    SingleReaction("915", Emojis.neonsquish),
    SingleReaction("swit", Emojis.sagelove),
    SingleReaction("lauten", Emojis.discord("🦑")),
    SingleReaction("mh", Emojis.discord("🌽")),
    SingleReaction("italian", Emojis.discord("🐧")),
    SingleReaction("ben", Emojis.discord("🤓")),
    SingleReaction("paige", Emojis.discord("🥛")),
    SingleReaction("bloom", Emojis.discord("🪷")),
    SingleReaction("glaze", Emojis.glaze),
    SingleReaction("kev", Emojis.kev),
    SingleReaction("neonbot", Emojis.discord("💙")),
  ];
}
