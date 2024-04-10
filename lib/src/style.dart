import 'package:nyxx/nyxx.dart';

class Colors {
  static final primary = DiscordColor.parseHexString('#03fccf');
}

final botFooter = EmbedFooterBuilder(text: "Made with 💙 by 915");

class Emojis {
  static final neonsquish =
      ReactionBuilder(name: "neonsquish", id: Snowflake(1041584725627781140));

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
