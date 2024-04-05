import 'package:nyxx/nyxx.dart';

import '../guild_preferences.dart';
import '../util.dart';
import '../style.dart';

extension GuildPreferencesEmbeddable on GuildPreferences {
  Future<EmbedBuilder> get asEmbed async {
    return EmbedBuilder(
      title: "Server config",
      description: [
        "**Announcements channel**: " +
            (await announcementsChannel?.channelMention ?? "None"),
        "**Voice channel**: " + (await voiceChannel?.channelMention ?? "None"),
        "**Premier team**: " + ((await premierTeam)?.riotId ?? "None"),
      ].join("\n"),
      color: Colors.primary,
      footer: botFooter,
    );
  }
}
