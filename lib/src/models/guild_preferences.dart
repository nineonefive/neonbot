import 'dart:async';

import 'package:nyxx/nyxx.dart';

import '../services/tracker/tracker.dart';
import 'memento.dart';
import 'premier_team.dart';
import 'valorant_regions.dart';

final logger = Logger("GuildPreferences");

class GuildPreferences implements Memento {
  final Snowflake guildId;

  PartialPremierTeam partialTeam;
  bool get hasPremierTeam => partialTeam != PartialPremierTeam.none;

  Snowflake announcementsChannel;
  bool get hasAnnouncementsChannel => announcementsChannel != Snowflake.zero;

  Snowflake voiceChannel;
  bool get hasVoiceChannel => voiceChannel != Snowflake.zero;

  Snowflake signupRole;
  bool get hasSignupRole => signupRole != Snowflake.zero;

  Region premierRegion;
  bool get hasPremierRegion => premierRegion != Region.none;

  GuildPreferences(
    this.guildId, {
    this.partialTeam = PartialPremierTeam.none,
    this.announcementsChannel = Snowflake.zero,
    this.voiceChannel = Snowflake.zero,
    this.signupRole = Snowflake.zero,
    this.premierRegion = Region.none,
  });

  /// Retrieves the premier team for this guild, throwing an error if one is not set
  Future<PremierTeam> get premierTeam async {
    if (!hasPremierTeam) {
      throw Exception("Calling get premierTeam on a guild without one set");
    }

    var team = await TrackerApi().getTeam(partialTeam.id);

    // Forcefully sync region to match team
    premierRegion = team.region;
    return team;
  }

  Map<String, dynamic> toJson() {
    return {
      "guildId": guildId.value,
      "premierTeam": partialTeam.toJson(),
      "announcementsChannel": announcementsChannel.value,
      "voiceChannel": voiceChannel.value,
      "signupRole": signupRole.value,
      "premierRegion": premierRegion.toJson(),
    };
  }

  @override
  Map<String, dynamic> getMemento() {
    return toJson();
  }

  @override
  void updateFromMemento(dynamic memento) {
    var other = GuildPreferences.fromJson(memento as Map<String, dynamic>);
    announcementsChannel = other.announcementsChannel;
    partialTeam = other.partialTeam;
    signupRole = other.signupRole;
    voiceChannel = other.voiceChannel;
    premierRegion = other.premierRegion;
  }

  static GuildPreferences fromJson(Map<String, dynamic> data) {
    return GuildPreferences(
      Snowflake(data["guildId"]),
      partialTeam: PartialPremierTeam.fromJson(
          data["premierTeam"] ?? PartialPremierTeam.none.toJson()),
      announcementsChannel: Snowflake(data["announcementsChannel"] ?? 0),
      voiceChannel: Snowflake(data["voiceChannel"] ?? 0),
      signupRole: Snowflake(data["signupRole"] ?? 0),
      premierRegion:
          Region.fromJson(data["premierRegion"] ?? Region.none.toJson()),
    );
  }

  @override
  String toString() {
    return 'GuildPreferences($guildId)';
  }
}
