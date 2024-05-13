import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:chaleno/chaleno.dart' show Parser, Chaleno;
import 'package:logging/logging.dart';
import 'package:puppeteer/plugins/stealth.dart';
import 'package:puppeteer/puppeteer.dart';

import 'exceptions.dart';
import 'tracker.dart';

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
    if (TrackerApi.cloudflareMode) {
      var browser = await puppeteer.launch(plugins: [StealthPlugin()]);
      var page = await browser.newPage();
      await page.setUserAgent(
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36");

      await page.goto(url.toString(), wait: Until.networkIdle);

      // Wait for tracker logo
      await page.waitForSelector(".trn-game-bar-company",
          timeout: Duration(seconds: 10));
      var result = await page.content;
      await browser.close();
      parser = Parser(result);
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
          var data = jsonDecode(text)["valorantPremier"];
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
