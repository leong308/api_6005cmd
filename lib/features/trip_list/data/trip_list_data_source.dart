import 'package:api_6005cmd/features/trip_list/model/trip_list_item_model.dart';

class TripListDataSource {
  Future<List<TripListItemModel>> fetchTrips() async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    return _seedTrips;
  }

  Future<TripListItemModel?> fetchTripById(String id) async {
    final trips = await fetchTrips();
    for (final trip in trips) {
      if (trip.id == id) {
        return trip;
      }
    }
    return null;
  }
}

final List<TripListItemModel> _seedTrips = [
  TripListItemModel(
    id: 'trip_001',
    destinationName: 'Tokyo',
    destinationCountry: 'Japan',
    latitude: 35.6762,
    longitude: 139.6503,
    startDate: DateTime(2026, 7, 12),
    endDate: DateTime(2026, 7, 18),
    preferences: ['culture', 'food'],
    travelNotes: 'Visit cultural places and try local restaurants.',
  ),
  TripListItemModel(
    id: 'trip_002',
    destinationName: 'Bangkok',
    destinationCountry: 'Thailand',
    latitude: 13.7563,
    longitude: 100.5018,
    startDate: DateTime(2026, 8, 4),
    endDate: DateTime(2026, 8, 10),
    preferences: ['shopping', 'food'],
    travelNotes: 'Street food crawl and night market visits.',
  ),
  TripListItemModel(
    id: 'trip_003',
    destinationName: 'Seoul',
    destinationCountry: 'South Korea',
    latitude: 37.5665,
    longitude: 126.9780,
    startDate: DateTime(2026, 9, 1),
    endDate: DateTime(2026, 9, 7),
    preferences: ['culture', 'family'],
    travelNotes: 'Palaces, museums, and family-friendly attractions.',
  ),
];
