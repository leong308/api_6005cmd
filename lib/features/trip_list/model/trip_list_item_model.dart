class TripListItemModel {
  TripListItemModel({
    required this.id,
    required this.destinationName,
    required this.destinationCountry,
    required this.latitude,
    required this.longitude,
    required this.startDate,
    required this.endDate,
    required this.preferences,
    required this.travelNotes,
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

  String get dateRangeLabel =>
      '${_formatDate(startDate)} - ${_formatDate(endDate)}';

  int get totalDays => endDate.difference(startDate).inDays + 1;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'destinationName': destinationName,
      'destinationCountry': destinationCountry,
      'latitude': latitude,
      'longitude': longitude,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'preferences': preferences,
      'travelNotes': travelNotes,
    };
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
