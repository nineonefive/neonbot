import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import 'models/valorant_regions.dart';

extension DataRetriever on Snowflake {
  String? get channelMention {
    return this == Snowflake.zero ? null : "<#$value>";
  }

  String? get roleMention {
    return this == Snowflake.zero ? null : "<@&$value>";
  }

  String? get userMention {
    return this == Snowflake.zero ? null : "<@$value>";
  }
}

extension FriendlyFormatting on Duration {
  String get formatted {
    String result = "";

    if (inMinutes < 1) {
      return "now";
    }

    if (inDays > 0) {
      result = "${inDays}d";
    } else if (inHours > 0) {
      result = "${inHours}h";
    } else if (inMinutes > 0) {
      result = "${inMinutes}m";
    }

    return result;
  }
}

/// Command check requiring the user to have role [roleName]
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

/// Turns a DateTime into a discord timestamp localied to region [region]
extension DiscordTimestamp on DateTime {
  String toDiscord(Region region) {
    var epochSeconds = millisecondsSinceEpoch ~/ 1000;
    var localized = region.localizeTime(this);
    var weekday = DateFormat("EEEE").format(localized);
    return "$weekday <t:$epochSeconds:t>";
  }
}

/// Downlaods an image at [url]
Future<List<int>> downloadImage(Uri url) async {
  var response = await http.get(url);
  return response.bodyBytes.toList();
}
