import 'package:nyxx/nyxx.dart';

import '../events.dart';
import 'preferences.dart';

final manEmoji =
    ReactionBuilder(name: "MAN", id: Snowflake(1213704607658807336));

class AutoreactService {
  static late final AutoreactService instance;

  static void init() {
    instance = AutoreactService._();
  }

  AutoreactService._() {
    eventBus.on<MessageCreateEvent>().listen(processMessage);
  }

  Future<void> processMessage(MessageCreateEvent event) async {
    var guildId = event.guildId;
    if (guildId == null) return;

    var words = event.message.content
        .split(" ")
        .map((word) => word.trim().toLowerCase());
    var shouldReact = words.any((word) => word == "man");

    if (shouldReact) {
      var gp = await GuildSettings.service.getForGuild(guildId);
      var isMilkTruckDiscord =
          gp.hasPremierTeam && gp.partialTeam.name == "Milk Truck#MILK";

      if (isMilkTruckDiscord) {
        await event.message.react(manEmoji);
      }
    }
  }
}
