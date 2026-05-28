import 'package:api_6005cmd/features/edit_trip/model/edit_trip_model.dart';
import 'package:api_6005cmd/features/trip_list/data/trip_list_data_source.dart';

class EditTripDataSource {
  EditTripDataSource(this.tripDataSource);

  final TripListDataSource tripDataSource;

  Future<EditTripModel?> fetchEditableTrip(String tripId) async {
    final trip = await tripDataSource.fetchTripById(tripId);
    if (trip == null) {
      return null;
    }
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
      updatedAt: DateTime(2026, 5, 20, 10, 0),
    );
  }
}
