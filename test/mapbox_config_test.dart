import 'package:api_6005cmd/core/config/mapbox_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses Mapbox access token from dotenv contents', () {
    const contents = '''
# Local map configuration
OTHER_VALUE=ignored
MAPBOX_ACCESS_TOKEN="pk.example-token"
''';

    expect(
      MapboxConfig.parseEnvironmentValue(contents, 'MAPBOX_ACCESS_TOKEN'),
      'pk.example-token',
    );
  });
}
