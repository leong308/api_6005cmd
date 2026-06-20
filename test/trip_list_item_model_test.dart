import 'package:api_6005cmd/features/trip_list/model/trip_list_item_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'rejects malformed trip dates instead of substituting the current date',
    () {
      expect(
        () => TripListItemModel.fromJson({
          'id': 'trip_001',
          'destinationName': 'Tokyo',
          'destinationCountry': 'Japan',
          'latitude': 35.6762,
          'longitude': 139.6503,
          'startDate': 'not-a-date',
          'endDate': '2026-07-18',
          'preferences': const <String>[],
        }),
        throwsFormatException,
      );
    },
  );
}
