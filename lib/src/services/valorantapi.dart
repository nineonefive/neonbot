import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/valorant_maps.dart';

class ValorantApi {
  static const String baseUrl = "https://valorant-api.com/v1";
  static const String imageBaseUrl = "https://media.valorant-api.com";
  static final _service = ValorantApi._();

  factory ValorantApi() => _service;

  final Map<ValorantMap, String> mapIds = {};

  ValorantApi._();

  /// Gets the ids for all of the maps
  Future<void> populateMapIds() async {
    var response = await http.get(Uri.parse("$baseUrl/maps"));
    var maps = jsonDecode(response.body)["data"] as List<dynamic>;

    for (var map in maps) {
      mapIds[ValorantMap.getByName(map["displayName"])] = map["uuid"];
    }
  }

  /// Returns the url for the given map's image
  Future<Uri?> getImageUrlForMap(ValorantMap map) async {
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
