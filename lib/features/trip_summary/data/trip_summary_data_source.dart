import 'package:api_6005cmd/core/api/api_client.dart';
import 'package:api_6005cmd/features/trip_list/data/trip_list_data_source.dart';
import 'package:api_6005cmd/features/trip_summary/model/trip_summary_model.dart';

class TripSummaryDataSource {
  TripSummaryDataSource(this.tripDataSource);

  final TripListDataSource tripDataSource;

  Future<TripSummaryModel?> fetchSummary(
    String tripId, {
    Map<String, int> recommendationLimits = const {},
    int routeMapDays = 0,
    Set<int> routeMapDayIndexes = const {},
    int availabilityDays = 1,
    bool forceRefresh = false,
  }) async {
    if (tripId.trim().isEmpty) {
      return null;
    }

    try {
      final query = _summaryQuery(
        recommendationLimits: recommendationLimits,
        routeMapDays: routeMapDays,
        routeMapDayIndexes: routeMapDayIndexes,
        availabilityDays: availabilityDays,
        forceRefresh: forceRefresh,
      );
      final response = await tripDataSource.apiClient.getJson(
        '/trips/$tripId/summary$query',
      );
      final data = response['data'];
      if (data is! Map) {
        throw const ApiException(
          500,
          'Trip summary response did not include an object.',
        );
      }
      return TripSummaryModel.fromJson(
        data.map((key, value) => MapEntry(key.toString(), value)),
      );
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<WalkingRouteModel> fetchWalkingRoute({
    required double fromLatitude,
    required double fromLongitude,
    required double toLatitude,
    required double toLongitude,
    String mode = 'walk',
  }) async {
    final query = Uri(
      queryParameters: {
        'fromLat': fromLatitude.toString(),
        'fromLng': fromLongitude.toString(),
        'toLat': toLatitude.toString(),
        'toLng': toLongitude.toString(),
        'mode': mode,
      },
    ).query;
    final response = await tripDataSource.apiClient.getJson(
      '/external/route?$query',
    );
    final data = response['data'];
    if (data is! Map) {
      throw const ApiException(
        500,
        'Walking route response did not include an object.',
      );
    }

    return WalkingRouteModel.fromJson(
      data.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
}

String _summaryQuery({
  required Map<String, int> recommendationLimits,
  required int routeMapDays,
  required Set<int> routeMapDayIndexes,
  required int availabilityDays,
  required bool forceRefresh,
}) {
  final safeLimits = recommendationLimits.entries
      .where((entry) => [3, 5, 10].contains(entry.value))
      .map((entry) => MapEntry(entry.key.trim().toLowerCase(), entry.value))
      .where((entry) => entry.key.isNotEmpty)
      .toList();
  final queryParameters = <String, String>{
    'routeMapDays': routeMapDays.clamp(0, 21).toString(),
    'availabilityDays': availabilityDays.clamp(0, 7).toString(),
  };
  if (forceRefresh) {
    queryParameters['refresh'] = 'true';
  }
  final safeRouteDayIndexes = routeMapDayIndexes
      .where((index) => index >= 0 && index < 21)
      .toList()
    ..sort();
  if (safeRouteDayIndexes.isNotEmpty) {
    queryParameters['routeMapDayIndexes'] = safeRouteDayIndexes.join(',');
  }

  if (safeLimits.isNotEmpty) {
    final serialized = safeLimits
        .map((entry) => '${entry.key}:${entry.value}')
        .join(',');
    queryParameters['recommendationLimits'] = serialized;
  }

  return '?${Uri(queryParameters: queryParameters).query}';
}
