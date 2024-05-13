import 'dart:convert';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../models/match_schedule.dart';
import '../models/valorant_regions.dart';
import '../neonbot.dart';
import 'tracker/tracker.dart';

class HttpServer {
  static late final HttpServer _instance;

  factory HttpServer() => _instance;

  static void init() {
    _instance = HttpServer._();
  }

  late final ReceivePort _receivePort;
  final Logger logger = Logger("HttpServer");

  HttpServer._() {
    _receivePort = ReceivePort();
    _receivePort.listen((message) async {
      var fakeRequest = message as _Request;
      var request = Request(fakeRequest.method, fakeRequest.requestedUri,
          body: fakeRequest.body);
      var response = await handler(request);
      if (response.statusCode != 200) {
        logger.warning("Error in http server: ${response.statusCode}");
      }
    });

    NeonBot().onShutdown(() => _receivePort.close());

    logger.info("Starting http server");
    Isolate.spawn(_isolateHandler, _receivePort.sendPort);
  }

  Handler get handler {
    final router = Router();

    router.get("/test", (Request request) async {
      return Response(200, body: request.url.toString());
    });

    router.post(
      "/schedule/<regionId>",
      (Request request, String regionId) async {
        final region = Region.fromId(regionId);

        if (region == Region.none) {
          return Response(404);
        }

        try {
          // Decode the post body and try to update the schedule in the database.
          var body = await request.readAsString();
          var data = jsonDecode(body) as Map<String, dynamic>;
          var schedule = MatchSchedule.fromJson(
              (data["schedule"] as List<dynamic>)
                  .map((e) => e as Map<String, dynamic>)
                  .toList());
          await Future(() => TrackerApi().updateSchedule(schedule, region));
          return Response(200);
        } catch (e) {
          return Response(401);
        }
      },
    );

    return router;
  }
}

void _isolateHandler(SendPort sendPort) async {
  final router = Router();

  // Handle all requests by returning 200 and then sending to the main isolate
  router.all("/<everything|.*>", (Request request) async {
    sendPort.send(await _Request.fromRequest(request));
    return Response(200);
  });

  final server = await shelf_io.serve(router, "0.0.0.0", 8080);
}

class _Request {
  final String method;
  final Uri requestedUri;
  final String body;

  _Request(this.method, this.requestedUri, {this.body = ""});

  static Future<_Request> fromRequest(Request request) async {
    return _Request(
      request.method,
      request.requestedUri,
      body: await request.readAsString(),
    );
  }
}
