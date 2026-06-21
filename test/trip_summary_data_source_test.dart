import 'dart:convert';

import 'package:api_6005cmd/core/api/api_client.dart';
import 'package:api_6005cmd/features/trip_list/data/trip_list_data_source.dart';
import 'package:api_6005cmd/features/trip_summary/data/trip_summary_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('force refresh adds the refresh query parameter', () async {
    Uri? requestedUri;
    final client = ApiClient(
      baseUrl: 'https://example.test/api',
      httpClient: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(jsonEncode({'message': 'Trip not found.'}), 404);
      }),
    );
    addTearDown(client.close);
    final dataSource = TripSummaryDataSource(
      TripListDataSource(apiClient: client),
    );

    expect(
      await dataSource.fetchSummary('trip_001', forceRefresh: true),
      isNull,
    );
    expect(requestedUri?.queryParameters['refresh'], 'true');
  });
}
