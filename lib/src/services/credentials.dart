import 'dart:convert';
import 'dart:io';

import '../cache.dart';

class CredentialsService {
  static final _instance = CredentialsService._();

  late final Cache<String, String> _cache;

  factory CredentialsService() => _instance;

  CredentialsService._() {
    _cache = Cache(retrieve: _loadToken);
  }

  Future<String> getToken(String serviceName) async {
    var result = await _cache.get(serviceName);

    if (result?.isEmpty ?? true) {
      throw StateError("No token found for name $serviceName");
    }

    return result!;
  }

  Future<String> _loadToken(String serviceName) async {
    // Load api keys
    var data = jsonDecode(File('api_keys.json').readAsStringSync());
    return data[serviceName] ?? "";
  }
}
