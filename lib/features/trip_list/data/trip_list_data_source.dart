import 'package:api_6005cmd/core/api/api_client.dart';
import 'package:api_6005cmd/features/add_trip/model/add_trip_draft_model.dart';
import 'package:api_6005cmd/features/edit_trip/model/edit_trip_model.dart';
import 'package:api_6005cmd/features/trip_list/model/trip_list_item_model.dart';

class TripListDataSource {
  TripListDataSource({ApiClient? apiClient})
    : apiClient = apiClient ?? ApiClient();

  final ApiClient apiClient;
  final Map<String, TripListItemModel> _knownTrips = {};

  void clearKnownTrips() {
    _knownTrips.clear();
  }

  Future<List<TripListItemModel>> fetchTrips() async {
    final response = await apiClient.getJson('/trips');
    final data = response['data'];
    if (data is! List) {
      throw const ApiException(500, 'Trips response did not include a list.');
    }
    final trips = data
        .map((item) => TripListItemModel.fromJson(_asJsonObject(item)))
        .toList();
    _knownTrips.clear();
    for (final trip in trips) {
      _knownTrips[trip.id] = trip;
    }
    return trips..sort((a, b) => a.id.compareTo(b.id));
  }

  Future<TripListItemModel?> fetchTripById(String id) async {
    if (id.trim().isEmpty) {
      return null;
    }

    try {
      final response = await apiClient.getJson('/trips/$id');
      final trip = TripListItemModel.fromJson(_asJsonObject(response['data']));
      _knownTrips[trip.id] = trip;
      return trip;
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        _knownTrips.remove(id);
        return null;
      }
      rethrow;
    }
  }

  Future<TripListItemModel> createTrip(AddTripDraftModel draft) async {
    final response = await apiClient.postJson('/trips', draft.toJson());
    final trip = TripListItemModel.fromJson(_asJsonObject(response['data']));
    _knownTrips[trip.id] = trip;
    return trip;
  }

  Future<TripListItemModel> updateTrip(EditTripModel trip) async {
    final response = await apiClient.putJson(
      '/trips/${trip.id}',
      trip.toJson(),
    );
    final updated = TripListItemModel.fromJson(_asJsonObject(response['data']));
    _knownTrips[updated.id] = updated;
    return updated;
  }

  Future<ReverseGeocodeResult> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final query = Uri(
      queryParameters: {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
      },
    ).query;
    final response = await apiClient.getJson(
      '/external/reverse-geocode?$query',
    );
    return ReverseGeocodeResult.fromJson(_asJsonObject(response['data']));
  }
}

class ReverseGeocodeResult {
  const ReverseGeocodeResult({
    required this.country,
    required this.countryCode,
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  final String country;
  final String countryCode;
  final String displayName;
  final double latitude;
  final double longitude;

  factory ReverseGeocodeResult.fromJson(Map<String, dynamic> json) {
    return ReverseGeocodeResult(
      country: json['country']?.toString() ?? '',
      countryCode: json['countryCode']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      latitude: _asCoordinate(json['latitude'], 'latitude', -90, 90),
      longitude: _asCoordinate(json['longitude'], 'longitude', -180, 180),
    );
  }
}

Map<String, dynamic> _asJsonObject(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const ApiException(500, 'API response did not include an object.');
}

double _asCoordinate(
  Object? value,
  String fieldName,
  double minimum,
  double maximum,
) {
  double? parsed;
  if (value is num) {
    parsed = value.toDouble();
  } else {
    parsed = double.tryParse(value?.toString() ?? '');
  }
  if (parsed == null ||
      !parsed.isFinite ||
      parsed < minimum ||
      parsed > maximum) {
    throw ApiException(
      502,
      'Reverse-geocode response included an invalid $fieldName.',
    );
  }
  return parsed;
}
