import 'dart:convert';

import 'package:api_6005cmd/core/api/api_client.dart';
import 'package:api_6005cmd/features/trip_list/data/trip_list_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('does not retain trips missing from a successful refresh', () async {
    var requestCount = 0;
    final client = ApiClient(
      baseUrl: 'https://example.test/api',
      httpClient: MockClient((_) async {
        requestCount++;
        return http.Response(
          jsonEncode({
            'data': requestCount == 1 ? [_tripJson] : <Object>[],
          }),
          200,
        );
      }),
    );
    addTearDown(client.close);
    final dataSource = TripListDataSource(apiClient: client);

    expect(await dataSource.fetchTrips(), hasLength(1));
    expect(await dataSource.fetchTrips(), isEmpty);
  });

  test('does not return a cached trip after the API returns 404', () async {
    var requestCount = 0;
    final client = ApiClient(
      baseUrl: 'https://example.test/api',
      httpClient: MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          return http.Response(
            jsonEncode({
              'data': [_tripJson],
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'message': 'Trip not found.'}), 404);
      }),
    );
    addTearDown(client.close);
    final dataSource = TripListDataSource(apiClient: client);

    await dataSource.fetchTrips();
    expect(await dataSource.fetchTripById('trip_001'), isNull);
  });

  test('rejects malformed reverse-geocode coordinates', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test/api',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': {
              'country': 'Malaysia',
              'countryCode': 'MY',
              'displayName': 'Malaysia',
              'latitude': 'not-a-number',
              'longitude': 101.9758,
            },
          }),
          200,
        ),
      ),
    );
    addTearDown(client.close);
    final dataSource = TripListDataSource(apiClient: client);

    await expectLater(
      dataSource.reverseGeocode(latitude: 4.2105, longitude: 101.9758),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 502)
            .having(
              (error) => error.message,
              'message',
              contains('invalid latitude'),
            ),
      ),
    );
  });
}

const Map<String, Object> _tripJson = {
  'id': 'trip_001',
  'destinationName': 'Tokyo',
  'destinationCountry': 'Japan',
  'latitude': 35.6762,
  'longitude': 139.6503,
  'startDate': '2026-07-12',
  'endDate': '2026-07-18',
  'preferences': ['food'],
  'travelNotes': 'Try local restaurants.',
};
