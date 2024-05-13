import 'package:timezone/timezone.dart' as tz;

/// Represents a Premier team zone
///
/// See https://valorant.fandom.com/wiki/Premier#Zones
enum Region {
  none("", "", ""),
  // Americas
  usEast(
    "NA_US_EAST",
    "US East",
    "America/New_York",
  ),
  usWest(
    "NA_US_WEST",
    "US West",
    "America/Los_Angeles",
  ),
  latamNorth(
    "LATAM_NORTH",
    "Latin America North",
    "America/New_York",
  ),
  latamSouth(
    "LATAM_SOUTH",
    "Latin America South",
    "America/Santiago",
  ),
  brazil(
    "BR_BRAZIL",
    "Brazil",
    "America/Sao_Paulo",
  ),

  // Pacific
  asiaEast(
    "AP_ASIA",
    "Asia",
    "Asia/Taipei",
  ),
  japan(
    "AP_JAPAN",
    "Japan",
    "Asia/Tokyo",
  ),
  oceania(
    "AP_OCEANIA",
    "Oceania",
    "Australia/Sydney",
  ),
  asiaSouth(
    "AP_SOUTH_ASIA",
    "South Asia",
    "Asia/Kolkata",
  ),
  korea(
    "KR_KOREA",
    "South Korea",
    "Asia/Seoul",
  ),

  // EMEA
  euNorth(
    "EU_NORTH",
    "North Europe",
    "Europe/London",
  ),
  euEast(
    "EU_EAST",
    "East Europe",
    "Europe/Warsaw",
  ),
  dach(
    "EU_DACH",
    "DACH",
    "Europe/Berlin",
  ),
  ibit(
    "EU_IBIT",
    "IBIT",
    "Europe/Madrid",
  ),
  france(
    "EU_FRANCE",
    "France",
    "Europe/Paris",
  ),
  middleEast(
    "EU_MIDDLE_EAST",
    "Middle East",
    "Asia/Qatar",
  ),
  turkiye("EU_TURKEY", "Türkiye", "Europe/Istanbul");

  /// The internal riot identifier
  final String id;

  /// The friendly display name
  final String name;

  /// The timezone identifier in the IANA database
  final String ianaTimezone;

  const Region(this.id, this.name, this.ianaTimezone);

  /// Returns the timezone for this region
  tz.Location get location => tz.getLocation(ianaTimezone);

  /// Localizes a time to this region's timezone
  tz.TZDateTime localizeTime(DateTime time) =>
      tz.TZDateTime.from(time, location);

  Map<String, String> toJson() {
    return {'id': id};
  }

  static Region fromJson(Map<String, dynamic> json) {
    return fromId(json['id'] ?? "");
  }

  /// Returns the region for [id]
  static Region fromId(String id) {
    for (var region in values) {
      if (region.id == id) {
        return region;
      }
    }
    return Region.none;
  }
}
