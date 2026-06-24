import 'package:api_6005cmd/core/config/mapbox_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses Mapbox access token from frontend JSON config', () {
    const contents = '''
{
  "MAPBOX_ACCESS_TOKEN": " pk.example-token "
}
''';

    expect(
      MapboxConfig.parseConfigValue(contents, 'MAPBOX_ACCESS_TOKEN'),
      'pk.example-token',
    );
  });

  test('loads Mapbox access token from frontend config path', () async {
    await MapboxConfig.load(
      readConfig: (uri) async {
        expect(uri.path, endsWith('/mapbox_config.local.json'));
        return '{"MAPBOX_ACCESS_TOKEN":"pk.runtime-token"}';
      },
    );

    expect(MapboxConfig.accessToken, 'pk.runtime-token');
  });
}
