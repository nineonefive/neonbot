import 'package:args/args.dart';
import 'package:neonbot/src/db.dart';
import 'dart:io' show Platform;
import 'package:neonbot/src/neonbot.dart';
import 'package:neonbot/src/premier_team.dart';
import 'package:logging/logging.dart';
import 'package:sqlite3/sqlite3.dart';

const String version = '0.0.1';

abstract class Secrets {
  static final String discordApiToken =
      Platform.environment['DISCORD_API_TOKEN'] ?? "";
}

ArgParser buildParser() {
  return ArgParser()
    ..addFlag(
      'version',
      negatable: false,
      help: 'Print the tool version.',
    )
    ..addFlag('debug', negatable: false, help: 'Enable debug mode.');
}

void printUsage(ArgParser argParser) {
  print('Usage: dart neonbot.dart <flags> [arguments]');
  print(argParser.usage);
}

void main(List<String> arguments) async {
  final ArgParser argParser = buildParser();
  try {
    final ArgResults results = argParser.parse(arguments);
    if (results.wasParsed('version')) {
      print('neonbot version: $version');
      return;
    }

    Level logLevel = Level.INFO;
    if (results.wasParsed('debug')) {
      logLevel = Level.FINE;
    }
    hierarchicalLoggingEnabled = true;
    Logger.root.level = logLevel;
    NeonBot.logLevel = logLevel;
    Logger.root.onRecord.listen((record) {
      String msg;
      if (record.error != null) {
        msg =
            '[${record.loggerName}] ${record.level.name}: ${record.time}: ${record.message} ${record.error}';
      } else {
        msg =
            '[${record.loggerName}] ${record.level.name}: ${record.time}: ${record.message}';
      }
      print(msg);
    });

    Db.init();
    launchBot();

    Finalizer<Database> _finalizer = Finalizer<Database>((db) => db.dispose());
    _finalizer.attach(Db.db!, Db.db!, detach: Db);

    // Get positional arguments with results.rest
  } on FormatException catch (e) {
    // Print usage information if an invalid argument was provided.
    print(e.message);
    print('');
    printUsage(argParser);
  }
}

void launchBot() async {
  var neonBot = await NeonBot.connect(Secrets.discordApiToken);
}
