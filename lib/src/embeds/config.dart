import 'package:nyxx/nyxx.dart';

import '../models/guild_preferences.dart';
import '../util.dart';
import '../style.dart';

extension GuildPreferencesEmbeddable on GuildPreferences {
  Future<EmbedBuilder> get asEmbed async {
    String voiceChannel = this.voiceChannel.channelMention ?? "None";
    String announcementsChannel =
        this.announcementsChannel.channelMention ?? "None";
    String teamName = hasPremierTeam ? partialTeam.name : "None";
    String regionName = hasPremierRegion ? premierRegion.name : "None";
    String roleName = signupRole.roleMention ?? "None";

    return EmbedBuilder(
      title: "Server config",
      description: [
        "**Announcements channel**: $announcementsChannel",
        "**Voice channel**: $voiceChannel",
        "**Signup role**: $roleName",
        "**Premier team**: $teamName",
        "**Premier region**: $regionName"
      ].join("\n"),
      color: Colors.primary,
      footer: botFooter,
    );
  }
}
