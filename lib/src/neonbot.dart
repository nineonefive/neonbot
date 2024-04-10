library neonbot;

import 'dart:async';

import 'package:neonbot/src/services/reactions.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'commands.dart';
import 'events.dart';
import 'services/db.dart';
import 'services/scheduler.dart';
import 'services/tracker/tracker.dart';

// Breakdown of intents:
// - guildMessageReactions: Needed for auto react or possibly signup mechanisms
// - guildMessages: Needed for autoreact
// - guildScheduledEvents: Needed for scheduling matches to the discord events list
// - messageContent: needed for autoreactions
final Flags<GatewayIntents> intents = GatewayIntents.guildMessageReactions |
    GatewayIntents.guildMessages |
    GatewayIntents.guildScheduledEvents |
    GatewayIntents.messageContent;

class NeonBot {
  static final NeonBot _instance = NeonBot._();

  factory NeonBot() => _instance;

  static bool useSelenium = false;
  static Level _logLevel = Level.INFO;
  static Level get logLevel => _logLevel;
  static set logLevel(Level level) {
    _logLevel = level;
    _instance.logger.level = level;
  }

  NeonBot._() {
    // Necessary for localization
    tz.initializeTimeZones();
  }

  final logger = Logger('neonbot');
  late final NyxxGateway client;
  late final User botUser;
  Snowflake get userId => botUser.id;

  /// Connects to discord using the provided token [token]
  ///
  /// Also initializes any needed services
  Future<void> connect(String token) async {
    // Connect to our local sqlite database
    DatabaseService.instance.init('local_db.db');
    Finalizer<Database> finalizer = Finalizer<Database>((db) => db.dispose());
    finalizer.attach(DatabaseService.instance, DatabaseService.service!,
        detach: DatabaseService.instance);

    // Register all slash commands before the bot connects
    final commands = CommandsPlugin(prefix: slashCommand())
      ..addCommand(config)
      ..addCommand(team)
      ..addCommand(schedule)
      ..addCommand(events)
      ..onCommandError.listen(errorHandler);

    // Finally connect using our api token
    client = await Nyxx.connectGateway(token, intents,
        options: GatewayClientOptions(plugins: [commands]));
    botUser = await client.users.fetchCurrentUser();
    logger.info("Logged in as ${botUser.username}");

    // Connect events to the event bus
    client.onMessageCreate.listen(eventBus.fire);
    client.onGuildCreate.listen(eventBus.fire);
    client.onInteractionCreate.listen(eventBus.fire);

    MatchScheduler.init(client);
    TrackerApi.init();
    AutoreactService.init();
  }
}
