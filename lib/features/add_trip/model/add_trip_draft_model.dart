class AddTripDraftModel {
  AddTripDraftModel({
    required this.destinationName,
    required this.destinationCountry,
    required this.latitude,
    required this.longitude,
    required this.startDate,
    required this.endDate,
    required this.preferences,
    required this.travelNotes,
  });

  final String destinationName;
  final String destinationCountry;
  final double latitude;
  final double longitude;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> preferences;
  final String travelNotes;

  Map<String, dynamic> toJson() {
    return {
      'destinationName': destinationName,
      'destinationCountry': destinationCountry,
      'latitude': latitude,
      'longitude': longitude,
      'startDate': startDate.toIso8601String().split('T').first,
      'endDate': endDate.toIso8601String().split('T').first,
      'preferences': preferences,
      'travelNotes': travelNotes,
    };
  }
}
