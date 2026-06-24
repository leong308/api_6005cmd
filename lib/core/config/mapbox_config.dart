import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MapboxConfig {
  const MapboxConfig._();

  static const String _compileTimeAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
  );

  static String _assetAccessToken = '';

  static String get accessToken {
    final compileTimeToken = _compileTimeAccessToken.trim();
    return compileTimeToken.isNotEmpty
        ? compileTimeToken
        : _assetAccessToken.trim();
  }

  static bool get isConfigured => accessToken.isNotEmpty;

  static Future<void> load({AssetBundle? bundle}) async {
    if (_compileTimeAccessToken.trim().isNotEmpty) {
      return;
    }

    try {
      final contents = await (bundle ?? rootBundle).loadString('backend/.env');
      _assetAccessToken =
          parseEnvironmentValue(contents, 'MAPBOX_ACCESS_TOKEN') ?? '';
    } catch (error) {
      debugPrint('Could not load .env for Mapbox configuration: $error');
      _assetAccessToken = '';
    }
  }

  @visibleForTesting
  static String? parseEnvironmentValue(String contents, String key) {
    for (final line in contents.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }

      final separatorIndex = trimmed.indexOf('=');
      if (separatorIndex <= 0) {
        continue;
      }

      final parsedKey = trimmed
          .substring(0, separatorIndex)
          .trim()
          .replaceFirst('\uFEFF', '');
      if (parsedKey != key) {
        continue;
      }

      var value = trimmed.substring(separatorIndex + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      return value.trim();
    }
    return null;
  }
}
