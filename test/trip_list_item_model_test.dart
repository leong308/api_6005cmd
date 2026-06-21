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

  test('rejects out-of-range coordinates and reversed dates', () {
    expect(
      () => TripListItemModel.fromJson({..._validTrip, 'latitude': 91}),
      throwsFormatException,
    );
    expect(
      () => TripListItemModel.fromJson({
        ..._validTrip,
        'startDate': '2026-07-20',
        'endDate': '2026-07-18',
      }),
      throwsFormatException,
    );
  });

  test('preserves server timestamps when provided', () {
    final trip = TripListItemModel.fromJson({
      ..._validTrip,
      'createdAt': '2026-06-20T08:00:00.000Z',
      'updatedAt': '2026-06-21T09:30:00.000Z',
    });

    expect(trip.createdAt, DateTime.utc(2026, 6, 20, 8));
    expect(trip.updatedAt, DateTime.utc(2026, 6, 21, 9, 30));
  });
}

const Map<String, Object> _validTrip = {
  'id': 'trip_001',
  'destinationName': 'Tokyo',
  'destinationCountry': 'Japan',
  'latitude': 35.6762,
  'longitude': 139.6503,
  'startDate': '2026-07-12',
  'endDate': '2026-07-18',
  'preferences': <String>[],
};
