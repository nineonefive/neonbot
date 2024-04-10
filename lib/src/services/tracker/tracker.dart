import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:chaleno/chaleno.dart' show Parser, Chaleno;
import 'package:logging/logging.dart';

import '../../cache.dart';
import '../../models/match_schedule.dart';
import '../../models/premier_team.dart';
import '../../models/valorant_regions.dart';
import '../../neonbot.dart';
import 'exceptions.dart';

class TrackerApi {
  static const teamCacheTime = Duration(minutes: 10);
  static const teamCacheSize = 100;
  static const scheduleCacheTime = Duration(days: 1);
  static const scheduleCacheSize = 25;
  static final riotIdPattern = RegExp(r'^[\w ]+#\w{4,6}$', unicode: true);

  static late final TrackerApi _instance;

  factory TrackerApi() {
    return _instance;
  }

  static void init() {
    _instance = TrackerApi._();
  }

  final Logger logger = Logger("TrackerApi");
  late final TrackerWorker _worker;
  late final Finalizer<TrackerWorker> _finalizer;

  // Maps team uuid to team
  late final Cache<String, PremierTeam> teamCache;

  // Maps region to upcoming matches
  late final Cache<Region, MatchSchedule> scheduleCache;

  TrackerApi._() {
    TrackerWorker.spawn().then((w) {
      _worker = w;
      _finalizer = Finalizer<TrackerWorker>((w) => w.close());
      _finalizer.attach(this, _worker, detach: this);
    });

    teamCache = Cache(
        ttl: teamCacheTime, maxSize: teamCacheSize, retrieve: _searchByUuid);
    scheduleCache = Cache(
        ttl: scheduleCacheTime,
        maxSize: scheduleCacheSize,
        retrieve: _downloadSchedule);
  }

  /// Retrieves a full premier team with id [uuid].
  ///
  /// Will throw a TrackerApiException if the team can't be retrieved
  Future<PremierTeam> getTeam(String uuid) async =>
      (await teamCache.get(uuid))!;

  /// Retrieves the upcoming matches for the given region [region]
  Future<MatchSchedule> getSchedule(Region region) async =>
      (await scheduleCache.get(region))!;

  /// Tries to find a premier team using the [riotId].
  ///
  /// This won't load all data (such as zone, standings). For that, you need
  /// to follow up by searching for the uuid
  Future<PartialPremierTeam> searchByRiotId(String riotId) async {
    if (!riotIdPattern.hasMatch(riotId)) {
      throw InvalidRiotIdException(riotId);
    }

    var url = Uri.https('api.tracker.gg',
        '/api/v1/valorant/search/by-query/$riotId', {'type': 'premier-team'});

    var parser = await Chaleno().load(url.toString());
    var body = parser?.getElementsByTagName('body')?.first.text;
    if (body != null) {
      var data = json.decode(body)["data"];
      for (dynamic resultSet in data["resultSets"]) {
        if (resultSet["type"] == 'premier-team' &&
            resultSet["results"].length == 1) {
          var team = resultSet["results"][0];
          var uuid = team["id"];
          riotId = team["name"];
          return PartialPremierTeam(uuid, riotId);
        }
      }
    }

    throw PremierTeamDoesntExistException(riotId);
  }

  Future<PremierTeam> _searchByUuid(String uuid) async {
    var url =
        Uri.https('tracker.gg', '/valorant/premier/teams/$uuid').toString();
    var response = await _worker.getValorantPremierData(url);
    if (response == null) {
      logger.shout("Failed to search for team $uuid, response is null");
      throw TrackerApiException(500);
    }

    logger.fine("Got data for team $uuid");
    var data = response["detailedRoster"] as Map<String, dynamic>;

    if (data["id"] == null) throw TrackerApiException(403);

    var region = Region.fromId(data["zone"]) ??
        (throw Exception("Got unknown region ${data["zone"]} from tracker"));

    var team = PremierTeam(data["id"], data["name"],
        region: region,
        rank: data["rank"],
        leagueScore: data["leagueScore"],
        division: data["divisionName"],
        imageUrl: data["icon"]["imageUrl"] as String);

    logger.fine("Downloaded team $team from tracker");
    return team;
  }

  /// Gets the upcoming matches for the given region [region] frp, tracler
  Future<MatchSchedule> _downloadSchedule(Region region) async {
    // Download the data with the worker since it's intensive. This avoids hanging
    // other computations in the main event queue
    var url = Uri.https(
            'tracker.gg', '/valorant/premier/standings', {'region': region.id})
        .toString();
    logger.fine("Fetching schedule for $region at $url");
    var response = await _worker.getValorantPremierData(url);

    if (response == null) {
      logger.shout("Received null response for schedule");
      throw TrackerApiException(500);
    }

    // Parse the matches into our appropriate structure. The events are stored under
    // the "events" key, so get that first.
    var data = response["schedules"] as Map<String, dynamic>;
    var matchDicts =
        (data.values.first as Map<String, dynamic>)["events"] as List<dynamic>;
    var matches = matchDicts
        .whereType<Map<String, dynamic>>()
        .map(Match.tryParse)
        .where((m) => m.matchType != MatchType.unknown)
        .toList();

    // Save the match schedule for future calls from other guilds
    var schedule = MatchSchedule(matches);
    return schedule;
  }
}

/// Worker that will download and parse large webpages for us
class TrackerWorker {
  static final Logger logger = Logger("TrackerWorker");
  final SendPort _commands;
  final ReceivePort _responses;
  final Map<int, Completer<Object?>> _activeRequests = {};
  int _idCounter = 0;
  bool _closed = false;

  Future<Map<String, dynamic>?> getValorantPremierData(String url) async {
    if (_closed) throw StateError('Closed');
    final completer = Completer<Object?>.sync();
    final id = _idCounter++;
    _activeRequests[id] = completer;
    _commands.send((id, url));
    return await completer.future as Map<String, dynamic>?;
  }

  static Future<TrackerWorker> spawn() async {
    // Create a receive port and add its initial message handler
    final initPort = RawReceivePort();
    final connection = Completer<(ReceivePort, SendPort)>.sync();
    initPort.handler = (initialMessage) {
      final commandPort = initialMessage as SendPort;
      connection.complete((
        ReceivePort.fromRawReceivePort(initPort),
        commandPort,
      ));
    };

    // Spawn the isolate.
    try {
      await Isolate.spawn(_startRemoteIsolate, (initPort.sendPort));
    } on Object {
      initPort.close();
      rethrow;
    }

    final (ReceivePort receivePort, SendPort sendPort) =
        await connection.future;

    return TrackerWorker._(receivePort, sendPort);
  }

  TrackerWorker._(this._responses, this._commands) {
    _responses.listen(_handleResponsesFromIsolate);
  }

  void _handleResponsesFromIsolate(dynamic message) {
    final (int id, Object? response) = message as (int, Object?);
    final completer = _activeRequests.remove(id)!;

    if (response is RemoteError) {
      completer.completeError(response);
    } else {
      completer.complete(response);
    }

    if (_closed && _activeRequests.isEmpty) _responses.close();
  }

  static Future<Map<String, dynamic>> parseTrackerPage(Uri url) async {
    Parser parser;
    if (NeonBot.useSelenium) {
      var result = await Process.run("python", ["tracker.py", url.toString()]);
      parser = Parser(result.stdout);
    } else {
      parser = (await Chaleno().load(url.toString()))!;
    }

    var scriptTags = parser.getElementsByTagName('script') ?? [];
    for (var scriptTag in scriptTags) {
      // Ignore external scripts like cloudflare
      if (scriptTag.src == null) {
        var text = scriptTag.innerHTML ?? "";
        if (text.contains("window.__INITIAL_STATE__ = ")) {
          text = text.replaceAll("window.__INITIAL_STATE__ = ", "");
          var data = json.decode(text)["valorantPremier"];
          return data;
        }
      }
    }

    var text = parser.html;
    if (text?.contains("[Error]: 403 Client Error") ?? false) {
      // We love cloudflare
      print("Cloud flare is stopping us");
      throw TrackerApiException(403);
    }

    print("No script tags found in webpage $url. Response: ${text ?? "null"}");
    throw TrackerApiException(404);
  }

  static void _handleCommandsToIsolate(
    ReceivePort receivePort,
    SendPort sendPort,
  ) {
    receivePort.listen((message) async {
      if (message == 'shutdown') {
        receivePort.close();
        return;
      }
      final (int id, String url) = message as (int, String);
      try {
        final data = await parseTrackerPage(Uri.parse(url));
        sendPort.send((id, data));
      } catch (e) {
        sendPort.send((id, RemoteError(e.toString(), '')));
      }
    });
  }

  static void _startRemoteIsolate(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    _handleCommandsToIsolate(receivePort, sendPort);
  }

  void close() {
    if (!_closed) {
      _closed = true;
      _commands.send('shutdown');
      if (_activeRequests.isEmpty) _responses.close();
    }
  }
}
