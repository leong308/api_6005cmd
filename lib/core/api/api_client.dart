import 'dart:convert';

import 'package:api_6005cmd/core/api/api_config.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'API error $statusCode: $message';
}

class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.selfApiBaseUrl;

  final http.Client _httpClient;
  final String _baseUrl;

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await _httpClient
        .get(_uri(path))
        .timeout(ApiConfig.requestTimeout);
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _httpClient
        .post(
          _uri(path),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(ApiConfig.requestTimeout);
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _httpClient
        .put(
          _uri(path),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(ApiConfig.requestTimeout);
    return _decodeObject(response);
  }

  Uri _uri(String path) {
    final base = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalizedPath');
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    final body = decoded is Map<String, dynamic> ? decoded : null;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = body?['message']?.toString() ?? response.reasonPhrase;
      throw ApiException(response.statusCode, message ?? 'Request failed.');
    }

    if (body == null) {
      throw const ApiException(500, 'API returned an invalid JSON object.');
    }

    return body;
  }
}
