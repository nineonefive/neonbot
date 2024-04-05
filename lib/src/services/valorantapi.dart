import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../style.dart';

class ValorantApi {
  static const String baseUrl = "https://valorant-api.com/v1";
  static const String imageBaseUrl = "https://media.valorant-api.com";
  static final service = ValorantApi._();

  final Map<ValorantMap, String> mapIds = {};

  ValorantApi._();

  Future<void> populateMapIds() async {
    var response = await http.get(Uri.parse("$baseUrl/maps"));
    var maps = jsonDecode(response.body)["data"] as List<dynamic>;

    for (var map in maps) {
      mapIds[ValorantMap.getByName(map["displayName"])] = map["uuid"];
    }
  }

  Future<Uri?> getImageForMap(ValorantMap map) async {
    if (mapIds.isEmpty) {
      await populateMapIds();
    }

    if (!mapIds.containsKey(map)) {
      return null;
    }

    var uuid = mapIds[map];
    var url = Uri.parse("$imageBaseUrl/maps/$uuid/splash.png");
    return url;
  }
}
