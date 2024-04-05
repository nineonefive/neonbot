import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

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
