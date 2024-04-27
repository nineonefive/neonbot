import 'dart:math';

import 'package:nyxx/nyxx.dart';

import '../events.dart';
import '../neonbot.dart';
import '../style.dart';
import '../util.dart';
import 'sentiment.dart';

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
        .where(messagePredicate)
        .listen(reactToMessage);

    _createIndex();
  }

  bool messagePredicate(MessageCreateEvent event) {
    // If discord didn't give us message content (due to insufficient permissions),
    // then don't pass to the react function
    if (event.message.content.isEmpty) {
      return false;
    }

    // Always listen in milk truck discord
    if (event.guildId == milkTruckDiscord) {
      return true;
    }

    // Check if we're mentioned
    if (event.mentions.any((u) => u.id == NeonBot().userId)) {
      return true;
    }

    return false;
  }

  /// Applies each reaction to the message [event.message]
  Future<void> reactToMessage(MessageCreateEvent event) async {
    var content = event.message.content;

    // Replace the neonbot mention with neonbot
    if (event.mentions.any((u) => u.id == NeonBot().userId)) {
      content =
          content.replaceFirst(NeonBot().userId.userMention ?? "", "neonbot");
    }

    var reactions = content
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

class RandomReaction extends MultiReaction {
  RandomReaction(super.keyword, super.emojis);

  @override
  Future<void> react(Message message) async {
    var index = Random().nextInt(emojis.length);
    await message.react(emojis[index]);
  }

  @override
  String toString() => "RandomReaction($keyword)";
}

class SentimentReaction extends Reaction {
  final Map<Sentiment, Reaction> reactions;
  Logger logger = Logger("SentimentReaction");

  SentimentReaction(super.keyword, this.reactions);

  @override
  Future<void> react(Message message) async {
    try {
      var sentiment = await SentimentService().getSentiment(message.content);
      var reaction = reactions[sentiment];
      await reaction?.react(message);
    } catch (e, stacktrace) {
      logger.warning("Error in react(): $e, $stacktrace");
    }
  }
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
    SentimentReaction("neonbot", {
      Sentiment.neutral: RandomReaction(
          "neutral", [Emojis.neonsweat, Emojis.neonlurk, Emojis.neonisee]),
      Sentiment.negative: RandomReaction("negative", [
        Emojis.neonsad,
        Emojis.neonangry,
        Emojis.neonrage,
        Emojis.neonthisisfine
      ]),
      Sentiment.positive: RandomReaction("positive", [
        Emojis.neonlove,
        Emojis.neonlove2,
        Emojis.neonwow,
        Emojis.discord("💙")
      ])
    }),
  ];
}
