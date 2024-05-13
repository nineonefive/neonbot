library neonbot;

import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'commands.dart';
import 'events.dart';
import 'services/credentials.dart';
import 'services/db.dart';
import 'services/reactions.dart';
import 'services/scheduler.dart';
import 'services/sentiment.dart';
import 'services/tracker/tracker.dart';
import 'services/http.dart';

// Breakdown of intents:
// - guildMessageReactions: Needed for auto react or possibly signup mechanisms
// - guildMembers: See what roles each user has in the scheduled events
// - guildMessages: Needed for autoreact
// - guildScheduledEvents: Needed for scheduling matches to the discord events list
// - guilds: So we receive GUILD_CREATE so we know what servers we're in
// - messageContent: needed for autoreactions
final Flags<GatewayIntents> intents = GatewayIntents.guildMessageReactions |
    GatewayIntents.guildMembers |
    GatewayIntents.guildMessages |
    GatewayIntents.guildScheduledEvents |
    GatewayIntents.guilds |
    GatewayIntents.messageContent;

class NeonBot {
  static final NeonBot _instance = NeonBot._();

  factory NeonBot() => _instance;

  static Level _logLevel = Level.INFO;
  static Level get logLevel => _logLevel;
  static set logLevel(Level level) {
    _logLevel = level;
    _instance.logger.level = level;
  }

  NeonBot._() {
    // Necessary for localization
    tz.initializeTimeZones();

    // listen to shutdown signals from OS
    ProcessSignal.sigint.watch().listen((s) => shutdown());
    ProcessSignal.sigterm.watch().listen((s) => shutdown());
  }

  late final NyxxGateway client;
  late final User botUser;
  Snowflake get userId => botUser.id;

  final logger = Logger('neonbot');

  /// Priority queue that puts tasks in order of first -> last
  final PriorityQueue<ShutdownTask> _shutdownTasks =
      PriorityQueue((a, b) => b.priority.compareTo(a.priority));

  /// Set of events that we broadcast from discord client to event bus
  final Set<StreamSubscription> _eventSubscriptions = {};

  /// Connects to discord using the provided token [token]
  ///
  /// Also initializes any needed services
  Future<void> connect() async {
    // Connect to our database
    DatabaseService.instance.init('local_db.db');

    // Register all slash commands before the bot connects
    final commands = CommandsPlugin(prefix: slashCommand())
      ..addCommand(config)
      ..addCommand(team)
      ..addCommand(schedule)
      ..addCommand(events)
      ..addCommand(restart)
      ..onCommandError.listen(errorHandler);

    // Get our discord token
    var discordToken = await CredentialsService().getToken("discord");

    // Finally connect using our api token
    client = await Nyxx.connectGateway(discordToken, intents,
        options: GatewayClientOptions(plugins: [commands]));
    botUser = await client.users.fetchCurrentUser();
    logger.info("Logged in as ${botUser.username} with user id $userId");

    // Set the neonbot status
    setPresence(online: true);
    Timer.periodic(Duration(minutes: 5), (timer) => setPresence(online: true));

    // Connect events to the event bus
    _eventSubscriptions
      ..add(client.onMessageCreate.listen(eventBus.fire))
      ..add(client.onGuildCreate.listen(eventBus.fire))
      ..add(client.onInteractionCreate.listen(eventBus.fire));

    // Initialize services that may require a connected discord client
    MatchScheduler.init(client);
    TrackerApi.init();
    AutoreactService.init();
    SentimentService.init();
    HttpServer.init();

    // Schedule core shutdown tasks:
    // - disable event bus
    // - shutting down the discord client
    // - closing db connection
    onShutdown(() async {
      for (var subscription in _eventSubscriptions) {
        subscription.cancel();
      }
      eventBus.destroy();
    }, priority: Priority.first);
    onShutdown(client.close, priority: Priority.last);
    onShutdown(DatabaseService.instance.close, priority: Priority.last);
  }

  /// Shuts down the bot, calling all shutdown tasks in order
  void shutdown() async {
    logger.info("Shutting down neonbot");
    setPresence(online: false);

    while (_shutdownTasks.isNotEmpty) {
      final task = _shutdownTasks.removeFirst();
      try {
        await task.run();
      } catch (e, stacktrace) {
        logger.warning("Error in shutdown task: $e, $stacktrace");
      }
    }

    exit(0);
  }

  void onShutdown(
    FutureOr<void> Function() run, {
    Priority priority = Priority.normal,
  }) {
    _shutdownTasks.add(ShutdownTask(
      run: run,
      priority: priority,
    ));
  }

  void setPresence({required bool online}) async {
    if (online) {
      client.updatePresence(PresenceBuilder(
        status: CurrentUserStatus.online,
        isAfk: false,
        activities: [
          ActivityBuilder(name: "VALORANT", type: ActivityType.game),
        ],
      ));
    } else {
      client.updatePresence(PresenceBuilder(
        status: CurrentUserStatus.offline,
        isAfk: true,
      ));
    }
  }
}

enum Priority implements Comparable {
  first(2),
  high(1),
  normal(0),
  low(-1),
  last(-2);

  final int value;

  const Priority(this.value);

  @override
  int compareTo(Object? other) => (other is Priority)
      ? value.compareTo(other.value)
      : throw Exception("Comparison only valid for priorities");
}

class ShutdownTask {
  final Priority priority;
  final FutureOr<void> Function() run;

  const ShutdownTask({required this.run, this.priority = Priority.normal});
}
