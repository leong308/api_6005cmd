import 'dart:convert';

import 'package:http/http.dart' as http;

class MapboxStyleException implements Exception {
  const MapboxStyleException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MapboxStyleLoader {
  const MapboxStyleLoader._();

  static final Map<String, Future<String>> _styleCache = {};

  static Future<String> load({
    required String styleId,
    required String accessToken,
    http.Client? client,
  }) {
    if (client != null) {
      return _fetchStyle(
        styleId: styleId,
        accessToken: accessToken,
        client: client,
      );
    }

    final cacheKey = '$styleId:${accessToken.hashCode}';
    final cachedStyle = _styleCache[cacheKey];
    if (cachedStyle != null) {
      return cachedStyle;
    }

    final request = _fetchStyle(
      styleId: styleId,
      accessToken: accessToken,
      client: http.Client(),
      closeClient: true,
    );
    final guardedRequest = request.catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      _styleCache.remove(cacheKey);
      Error.throwWithStackTrace(error, stackTrace);
    });
    _styleCache[cacheKey] = guardedRequest;
    return guardedRequest;
  }

  static Future<String> _fetchStyle({
    required String styleId,
    required String accessToken,
    required http.Client client,
    bool closeClient = false,
  }) async {
    try {
      final uri = Uri.https('api.mapbox.com', '/styles/v1/mapbox/$styleId', {
        'access_token': accessToken,
      });
      final response = await client.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MapboxStyleException(
          'Mapbox style request failed (${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const MapboxStyleException(
          'Mapbox returned an invalid style document.',
        );
      }

      final style = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      return jsonEncode(
        makeMapLibreCompatible(
          style,
          styleId: styleId,
          accessToken: accessToken,
        ),
      );
    } on FormatException {
      throw const MapboxStyleException('Mapbox returned malformed style JSON.');
    } finally {
      if (closeClient) {
        client.close();
      }
    }
  }

  static Map<String, dynamic> makeMapLibreCompatible(
    Map<String, dynamic> original, {
    required String styleId,
    required String accessToken,
  }) {
    final style = _deepCopy(original);
    for (final key in const [
      'created',
      'draft',
      'id',
      'modified',
      'name',
      'owner',
      'projection',
      'protected',
      'visibility',
    ]) {
      style.remove(key);
    }

    final sources = style['sources'];
    if (sources is Map) {
      for (final value in sources.values) {
        if (value is! Map) {
          continue;
        }
        final sourceUrl = value['url'];
        if (sourceUrl is String && sourceUrl.startsWith('mapbox://')) {
          value['url'] = _tileJsonUrl(sourceUrl, accessToken);
        }
      }
    }

    final sprite = style['sprite'];
    if (sprite is String && sprite.startsWith('mapbox://sprites/')) {
      style['sprite'] = _spriteUrl(sprite, accessToken);
    }

    final glyphs = style['glyphs'];
    if (glyphs is String && glyphs.startsWith('mapbox://fonts/')) {
      style['glyphs'] = _glyphUrl(glyphs, accessToken);
    }

    _addBuildingExtrusions(style);
    return style;
  }

  static Map<String, dynamic> _deepCopy(Map<String, dynamic> value) {
    return (jsonDecode(jsonEncode(value)) as Map).map(
      (key, item) => MapEntry(key.toString(), item),
    );
  }

  static String _tileJsonUrl(String sourceUrl, String accessToken) {
    final tilesetIds = sourceUrl.substring('mapbox://'.length);
    return 'https://api.mapbox.com/v4/$tilesetIds.json'
        '?secure&access_token=${Uri.encodeQueryComponent(accessToken)}';
  }

  static String _spriteUrl(String spriteUrl, String accessToken) {
    final stylePath = spriteUrl.substring('mapbox://sprites/'.length);
    return Uri.https('api.mapbox.com', '/styles/v1/$stylePath/sprite', {
      'access_token': accessToken,
    }).toString();
  }

  static String _glyphUrl(String glyphUrl, String accessToken) {
    final fontPath = glyphUrl.substring('mapbox://fonts/'.length);
    return 'https://api.mapbox.com/fonts/v1/$fontPath'
        '?access_token=${Uri.encodeQueryComponent(accessToken)}';
  }

  static void _addBuildingExtrusions(Map<String, dynamic> style) {
    final layers = style['layers'];
    final sources = style['sources'];
    if (layers is! List || sources is! Map) {
      return;
    }
    if (layers.any(
      (layer) => layer is Map && layer['id'] == 'smart-travel-3d-buildings',
    )) {
      return;
    }

    String? buildingSource;
    for (final entry in sources.entries) {
      final source = entry.value;
      if (source is Map &&
          source['type'] == 'vector' &&
          source['url'] is String &&
          (source['url'] as String).contains('mapbox-streets-v8')) {
        buildingSource = entry.key.toString();
        break;
      }
    }
    if (buildingSource == null) {
      return;
    }

    final extrusionLayer = <String, dynamic>{
      'id': 'smart-travel-3d-buildings',
      'type': 'fill-extrusion',
      'source': buildingSource,
      'source-layer': 'building',
      'minzoom': 14,
      'filter': ['==', 'extrude', 'true'],
      'paint': {
        'fill-extrusion-color': '#d5d0c8',
        'fill-extrusion-height': [
          'interpolate',
          ['linear'],
          ['zoom'],
          14,
          0,
          14.6,
          ['get', 'height'],
        ],
        'fill-extrusion-base': [
          'interpolate',
          ['linear'],
          ['zoom'],
          14,
          0,
          14.6,
          ['get', 'min_height'],
        ],
        'fill-extrusion-opacity': 0.82,
      },
    };

    final firstLabelIndex = layers.indexWhere(
      (layer) => layer is Map && layer['type'] == 'symbol',
    );
    if (firstLabelIndex < 0) {
      layers.add(extrusionLayer);
    } else {
      layers.insert(firstLabelIndex, extrusionLayer);
    }
  }
}
