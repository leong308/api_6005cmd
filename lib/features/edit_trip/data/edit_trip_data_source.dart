import 'package:api_6005cmd/features/edit_trip/model/edit_trip_model.dart';
import 'package:api_6005cmd/features/trip_list/data/trip_list_data_source.dart';
import 'package:api_6005cmd/features/trip_list/model/trip_list_item_model.dart';

class EditTripDataSource {
  EditTripDataSource(this.tripDataSource);

  final TripListDataSource tripDataSource;

  Future<EditTripModel?> fetchEditableTrip(String tripId) async {
    if (tripId.trim().isEmpty) {
      return null;
    }

    final trip = await tripDataSource.fetchTripById(tripId);
    if (trip == null) {
      return null;
    }
    return _fromTrip(trip);
  }

  Future<EditTripModel> updateTrip(EditTripModel trip) async {
    final updated = await tripDataSource.updateTrip(trip);
    return _fromTrip(updated);
  }

  Future<ReverseGeocodeResult> reverseGeocode({
    required double latitude,
    required double longitude,
  }) {
    return tripDataSource.reverseGeocode(
      latitude: latitude,
      longitude: longitude,
    );
  }

  EditTripModel _fromTrip(TripListItemModel trip) {
    return EditTripModel(
      id: trip.id,
      destinationName: trip.destinationName,
      destinationCountry: trip.destinationCountry,
      latitude: trip.latitude,
      longitude: trip.longitude,
      startDate: trip.startDate,
      endDate: trip.endDate,
      preferences: trip.preferences,
      travelNotes: trip.travelNotes,
      updatedAt: DateTime.now(),
    );
  }
}
