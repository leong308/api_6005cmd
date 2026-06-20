import 'package:api_6005cmd/core/api/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('wraps malformed successful JSON in ApiException', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test/api',
      httpClient: MockClient(
        (_) async => http.Response('<html>not json</html>', 200),
      ),
    );
    addTearDown(client.close);

    await expectLater(
      client.getJson('/trips'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 502)
            .having(
              (error) => error.message,
              'message',
              'API returned malformed JSON.',
            ),
      ),
    );
  });
}
