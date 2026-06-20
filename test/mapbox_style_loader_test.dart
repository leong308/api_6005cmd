import 'package:api_6005cmd/core/config/mapbox_style_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rewrites Mapbox URLs and adds a 3D building layer', () {
    final style = MapboxStyleLoader.makeMapLibreCompatible(
      {
        'version': 8,
        'name': 'Streets',
        'owner': 'mapbox',
        'projection': {'name': 'mercator'},
        'sprite': 'mapbox://sprites/mapbox/streets-v12',
        'glyphs': 'mapbox://fonts/mapbox/{fontstack}/{range}.pbf',
        'sources': {
          'composite': {
            'type': 'vector',
            'url':
                'mapbox://mapbox.mapbox-streets-v8,'
                'mapbox.mapbox-terrain-v2',
          },
        },
        'layers': [
          {'id': 'land', 'type': 'fill', 'source': 'composite'},
          {'id': 'labels', 'type': 'symbol', 'source': 'composite'},
        ],
      },
      styleId: 'streets-v12',
      accessToken: 'pk.test',
    );

    expect(style, isNot(contains('owner')));
    expect(style, isNot(contains('projection')));
    expect(style['sprite'], contains('api.mapbox.com/styles/v1'));
    expect(style['glyphs'], contains('api.mapbox.com/fonts/v1'));

    final sources = style['sources'] as Map;
    expect(
      (sources['composite'] as Map)['url'],
      contains('api.mapbox.com/v4/mapbox.mapbox-streets-v8'),
    );

    final layers = style['layers'] as List;
    final extrusionIndex = layers.indexWhere(
      (layer) => layer is Map && layer['id'] == 'smart-travel-3d-buildings',
    );
    final labelIndex = layers.indexWhere(
      (layer) => layer is Map && layer['id'] == 'labels',
    );
    expect(extrusionIndex, greaterThanOrEqualTo(0));
    expect(extrusionIndex, lessThan(labelIndex));
    expect((layers[extrusionIndex] as Map)['type'], 'fill-extrusion');
  });
}
