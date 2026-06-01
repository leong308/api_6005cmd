import 'package:api_6005cmd/core/api/api_client.dart';
import 'package:api_6005cmd/features/trip_list/data/trip_list_data_source.dart';
import 'package:api_6005cmd/features/trip_summary/model/trip_summary_model.dart';

class TripSummaryDataSource {
  TripSummaryDataSource(this.tripDataSource);

  final TripListDataSource tripDataSource;

  Future<TripSummaryModel?> fetchSummary(String tripId) async {
    if (tripId.trim().isEmpty) {
      return null;
    }

    try {
      final response = await tripDataSource.apiClient.getJson(
        '/trips/$tripId/summary',
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
}
