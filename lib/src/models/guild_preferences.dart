import 'dart:async';

import 'package:nyxx/nyxx.dart';

import '../services/tracker/tracker.dart';
import 'premier_team.dart';
import 'valorant_regions.dart';

final logger = Logger("GuildPreferences");

class GuildPreferences {
  final Snowflake guildId;

  PartialPremierTeam partialTeam;
  bool get hasPremierTeam => partialTeam != PartialPremierTeam.none;

  Snowflake announcementsChannel;
  bool get hasAnnouncementsChannel => announcementsChannel != Snowflake.zero;

  Snowflake voiceChannel;
  bool get hasVoiceChannel => voiceChannel != Snowflake.zero;

  Snowflake signupRole;
  bool get hasSignupRole => signupRole != Snowflake.zero;

  GuildPreferences(
    this.guildId, {
    this.partialTeam = PartialPremierTeam.none,
    this.announcementsChannel = Snowflake.zero,
    this.voiceChannel = Snowflake.zero,
    this.signupRole = Snowflake.zero,
  });

  /// Retrieves the premier team for this guild, throwing an error if one is not set
  Future<PremierTeam> get premierTeam async {
    return hasPremierTeam
        ? await TrackerApi().getTeam(partialTeam.id)
        : throw Exception("Calling get premierTeam on a guild without one set");
  }

  /// Retrieves the zone for this guild
  /// Todo: Store zone in guild preferences directly
  Future<Region> get region async {
    if (!hasPremierTeam) return Region.usEast;
    var team = await premierTeam;
    return team.region;
  }

  Map<String, dynamic> toJson() {
    return {
      "guildId": guildId.value,
      "premierTeam": partialTeam.toJson(),
      "announcementsChannel": announcementsChannel.value,
      "voiceChannel": voiceChannel.value,
      "signupRole": signupRole.value
    };
  }

  static GuildPreferences fromJson(Map<String, dynamic> data) {
    return GuildPreferences(
      Snowflake(data["guildId"]),
      partialTeam: PartialPremierTeam.fromJson(data["premierTeam"]),
      announcementsChannel: Snowflake(data["announcementsChannel"] ?? 0),
      voiceChannel: Snowflake(data["voiceChannel"] ?? 0),
      signupRole: Snowflake(data["signupRole"] ?? 0),
    );
  }

  @override
  String toString() {
    return 'GuildPreferences($guildId)';
  }
}
