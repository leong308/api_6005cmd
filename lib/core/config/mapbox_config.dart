import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MapboxConfig {
  const MapboxConfig._();

  static const String _compileTimeAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
  );
  static const String _configPath = String.fromEnvironment(
    'MAPBOX_CONFIG_PATH',
    defaultValue: 'mapbox_config.local.json,mapbox_config.json',
  );

  static String _runtimeAccessToken = '';

  static String get accessToken {
    final compileTimeAccessToken = _compileTimeAccessToken.trim();
    return compileTimeAccessToken.isNotEmpty
        ? compileTimeAccessToken
        : _runtimeAccessToken.trim();
  }

  static bool get isConfigured => accessToken.isNotEmpty;

  static Future<void> load({
    Future<String> Function(Uri uri)? readConfig,
  }) async {
    if (_compileTimeAccessToken.trim().isNotEmpty) {
      return;
    }

    try {
      _runtimeAccessToken = await _loadRuntimeAccessToken(readConfig);
    } catch (error) {
      _runtimeAccessToken = '';
      debugPrint('Could not load Mapbox frontend config: $error');
    }

    if (!isConfigured) {
      debugPrint(
        'MAPBOX_ACCESS_TOKEN is not configured. Set it in '
        'web/mapbox_config.local.json or pass it with --dart-define.',
      );
    }
  }

  static Future<String> _loadRuntimeAccessToken(
    Future<String> Function(Uri uri)? readConfig,
  ) async {
    for (final configPath in _configPath.split(',')) {
      final trimmedPath = configPath.trim();
      if (trimmedPath.isEmpty) {
        continue;
      }

      final configUri = Uri.base.resolve(trimmedPath);
      final contents = readConfig == null
          ? await _readConfig(configUri)
          : await readConfig(configUri);
      final accessToken = parseConfigValue(contents, 'MAPBOX_ACCESS_TOKEN');
      if (accessToken != null && accessToken.isNotEmpty) {
        return accessToken;
      }
    }

    return '';
  }

  static Future<String> _readConfig(Uri uri) async {
    final response = await http.get(uri);
    if (response.statusCode == 404) {
      return '{}';
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Mapbox config request failed with ${response.statusCode}.',
      );
    }
    return response.body;
  }

  @visibleForTesting
  static String? parseConfigValue(String contents, String key) {
    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final value = decoded[key];
    if (value is! String) {
      return null;
    }
    return value.trim();
  }
}
