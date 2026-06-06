import 'dart:async';
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
  String? _authToken;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    try {
      final response = await _httpClient
          .get(_uri(path), headers: _headers())
          .timeout(ApiConfig.requestTimeout);
      return _decodeObject(response);
    } on TimeoutException {
      throw ApiException(0, 'Backend request timed out: ${_uri(path)}');
    } on http.ClientException catch (error) {
      throw ApiException(
        0,
        'Could not reach backend. Check backend is running and CORS allows this Flutter port. ${error.message}',
      );
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _httpClient
          .post(
            _uri(path),
            headers: _headers(contentType: true),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.requestTimeout);
      return _decodeObject(response);
    } on TimeoutException {
      throw ApiException(0, 'Backend request timed out: ${_uri(path)}');
    } on http.ClientException catch (error) {
      throw ApiException(
        0,
        'Could not reach backend. Check backend is running and CORS allows this Flutter port. ${error.message}',
      );
    }
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _httpClient
          .put(
            _uri(path),
            headers: _headers(contentType: true),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.requestTimeout);
      return _decodeObject(response);
    } on TimeoutException {
      throw ApiException(0, 'Backend request timed out: ${_uri(path)}');
    } on http.ClientException catch (error) {
      throw ApiException(
        0,
        'Could not reach backend. Check backend is running and CORS allows this Flutter port. ${error.message}',
      );
    }
  }

  Uri _uri(String path) {
    final base = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalizedPath');
  }

  Map<String, String> _headers({bool contentType = false}) {
    return {
      if (contentType) 'Content-Type': 'application/json',
      if (_authToken != null && _authToken!.isNotEmpty)
        'Authorization': 'Bearer $_authToken',
    };
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
