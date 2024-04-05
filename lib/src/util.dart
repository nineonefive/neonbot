import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:timezone/timezone.dart' as tz;

extension ChannelRetriever on Snowflake {
  Future<String?> get channelMention async {
    try {
      return "<#$value>";
    } catch (e) {
      return null;
    }
  }
}

extension FriendlyFormatting on Duration {
  String get formatted {
    String result = "";

    if (inMinutes < 1) {
      return "now";
    }

    if (inDays > 0) {
      result = "${inDays}d ago";
    } else if (inHours > 0) {
      result = "${inHours}h ago";
    } else if (inMinutes > 0) {
      result = "${inMinutes}m ago";
    }

    return result;
  }
}

class UserHasRoleCheck extends Check {
  UserHasRoleCheck(String roleName)
      : super((context) async {
          if (context.guild?.ownerMember.id == context.user.id) {
            return true;
          }

          // Get the roles of the user and check if any match "neonbot admin"
          var partialRoles = context.member?.roles ?? [];
          var futures = partialRoles.map((pr) async {
            var role = await pr.manager.fetch(pr.id);
            return role.name == roleName;
          });

          // Map the List<Future<bool>> to a Future<bool> with the equivalent
          // of an any() operation
          var future = Future.wait(futures).then((results) =>
              results.isNotEmpty && results.reduce((x, y) => x | y));
          return await future;
        }, name: "has-role $roleName");
}

Snowflake? maybeNullSnowflake(int? value) {
  if (value == null) {
    return null;
  }

  return Snowflake(value);
}

var regionLocations = {
  // Americas
  "NA_US_EAST": "America/New_York",
  "NA_US_WEST": "America/Los_Angeles",
  "LATAM_NORTH": "America/New_York",
  "LATAM_SOUTH": "America/Santiago",
  "BR_BRAZIL": "America/Sao_Paulo",

  // Asia
  "AP_ASIA": "Asia/Taipei",
  "AP_JAPAN": "Asia/Tokyo",
  "AP_OCEANIA": "Australia/Sydney",
  "AP_SOUTH_ASIA": "Asia/Kolkata",
  "KR_KOREA": "Asia/Seoul",

  // EMEA
  "EU_NORTH": "Europe/London",
  "EU_EAST": "Europe/Warsaw",
  "EU_DACH": "Europe/Berlin",
  "EU_IBIT": "Europe/Madrid",
  "EU_FRANCE": "Europe/Paris",
  "EU_MIDDLE_EAST": "Asia/Qatar",
  "EU_TURKEY": "Europe/Istanbul"
}.map((k, v) => MapEntry(k, tz.getLocation(v)));

extension DiscordTimestamp on DateTime {
  String toDiscord(String region) {
    var epochSeconds = millisecondsSinceEpoch ~/ 1000;
    var localized = tz.TZDateTime.from(this, regionLocations[region]!);
    var weekday = DateFormat("EEEE").format(localized);
    return "$weekday <t:$epochSeconds:t>";
  }
}

Future<List<int>> downloadImage(Uri url) async {
  var response = await http.get(url);
  return response.bodyBytes.toList();
}
