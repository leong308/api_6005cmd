class EditTripModel {
  const EditTripModel({
    required this.id,
    required this.destinationName,
    required this.destinationCountry,
    required this.latitude,
    required this.longitude,
    required this.startDate,
    required this.endDate,
    required this.preferences,
    required this.travelNotes,
    required this.updatedAt,
  });

  final String id;
  final String destinationName;
  final String destinationCountry;
  final double latitude;
  final double longitude;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> preferences;
  final String travelNotes;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'destinationName': destinationName,
      'destinationCountry': destinationCountry,
      'latitude': latitude,
      'longitude': longitude,
      'startDate': startDate.toIso8601String().split('T').first,
      'endDate': endDate.toIso8601String().split('T').first,
      'preferences': preferences,
      'travelNotes': travelNotes,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
