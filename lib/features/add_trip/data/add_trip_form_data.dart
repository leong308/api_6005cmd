import 'package:api_6005cmd/features/add_trip/model/add_trip_draft_model.dart';

class AddTripFormData {
  const AddTripFormData._();

  static const List<String> preferenceOptions = ['culture', 'food', 'nature', 'shopping', 'family'];

  static AddTripDraftModel seedDraft() {
    return AddTripDraftModel(
      destinationName: 'Tokyo',
      destinationCountry: 'Japan',
      latitude: 35.6762,
      longitude: 139.6503,
      startDate: DateTime(2026, 7, 12),
      endDate: DateTime(2026, 7, 18),
      preferences: ['culture', 'food'],
      travelNotes: 'Visit cultural places and try local restaurants.',
    );
  }
}
