import 'package:nyxx/nyxx.dart';

class Colors {
  static final primary = DiscordColor.parseHexString('#03fccf');
}

final botFooter = EmbedFooterBuilder(text: "Made with 💙 by 915");

class Emojis {
  static final neonsquish =
      ReactionBuilder(name: "neonsquish", id: Snowflake(1041584725627781140));

  static final neonsweat =
      ReactionBuilder(name: "neonsweat", id: Snowflake(954830684080459817));

  static final neonlove =
      ReactionBuilder(name: "neonlove", id: Snowflake(954830472561692765));

  static final neonlove2 =
      ReactionBuilder(name: "neonlove2", id: Snowflake(1140755039179260055));

  static final neonsad =
      ReactionBuilder(name: "neonsad", id: Snowflake(1049438054714192074));

  static final neonangry =
      ReactionBuilder(name: "neonangry", id: Snowflake(1049438000335044668));

  static final neonrage =
      ReactionBuilder(name: "neonrage", id: Snowflake(1049438130282967050));

  static final neonthisisfine = ReactionBuilder(
      name: "neonthisisfine", id: Snowflake(1140755514188382248));

  static final oridead =
      ReactionBuilder(name: "oridead", id: Snowflake(1230986215554027601));

  static final oriheart =
      ReactionBuilder(name: "oriheart", id: Snowflake(1230986271376281610));

  static final sagelove =
      ReactionBuilder(name: "sagelove", id: Snowflake(1226382840422207548));

  static final glaze =
      ReactionBuilder(name: "glaze", id: Snowflake(1226388046203584552));

  static final kev =
      ReactionBuilder(name: "kev", id: Snowflake(1226386493774237738));

  static final man =
      ReactionBuilder(name: "MAN", id: Snowflake(1213704607658807336));

  static final costco =
      ReactionBuilder(name: "costco", id: Snowflake(1167897307811954828));

  static final alecks =
      ReactionBuilder(name: "alecks", id: Snowflake(1143687438045302864));

  static discord(String unicode) => ReactionBuilder(name: unicode, id: null);
}
