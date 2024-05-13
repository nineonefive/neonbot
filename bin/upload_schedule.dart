import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:neonbot/src/models/valorant_regions.dart';
import 'package:neonbot/src/services/tracker/tracker.dart';

void main(List<String> arguments) async {
  final ip = arguments.first;

  // Start tracker service to download the schedule
  TrackerApi.init();

  for (var region in Region.values) {
    await Future.delayed(Duration(seconds: 5));
    if (region == Region.none) {
      continue;
    }

    print("Looking up region ${region.name}");
    var schedule = await TrackerApi().downloadSchedule(region);

    print("Uploading to server");
    await http.post(
      Uri.http("$ip:8080", "/schedule/${region.id}"),
      body: jsonEncode({"schedule": schedule.toJson()}),
    );
  }
}
