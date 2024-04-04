library neonbot;

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import 'commands.dart';

// Determined with the discord website
final Flags<GatewayIntents> intents =
    GatewayIntents.guildMessageReactions | GatewayIntents.guildMessages;

class NeonBot {
  static final _commands = CommandsPlugin(prefix: slashCommand());
  static NeonBot? _instance;
  static NeonBot get instance => _instance!;
  static final logger = Logger('neonbot');
  static Level _logLevel = Level.INFO;

  static Level get logLevel => _logLevel;
  static set logLevel(Level level) {
    _logLevel = level;
    logger.level = level;
  }

  late final NyxxGateway client;
  late final User botUser;
  late final Logger log;

  /// Connects to discord using the provided token [token]
  static Future<NeonBot> connect(String token) async {
    // Only connect once. If we already have an active client, return it
    if (_instance != null) {
      return Future.value(_instance);
    }

    // Register all slash commands before the bot connects
    var commands = getAllCommands();
    logger.info("Registering commands");
    for (var cmd in commands) {
      _commands.addCommand(cmd);
    }

    _commands.onCommandError.listen((error) {
      if (error is CheckFailedException) {
        error.context.respond(
            MessageBuilder(content: ":x: Sorry, you can't use that command!"));
      }
      logger.info(error);
    });

    // Finally connect using our api token
    var client = await Nyxx.connectGateway(token, intents,
        options: GatewayClientOptions(plugins: [_commands]));
    var botUser = await client.users.fetchCurrentUser();
    logger.info("Logged in as ${botUser.username}");

    // Return the instance
    _instance = NeonBot._create(client, botUser);
    return Future.value(_instance);
  }

  NeonBot._create(this.client, this.botUser);
}
