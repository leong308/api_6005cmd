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

  factory TripListItemModel.fromJson(Map<String, dynamic> json) {
    return TripListItemModel(
      id: _asString(json['id']),
      destinationName: _asString(json['destinationName']),
      destinationCountry: _asString(json['destinationCountry']),
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
      startDate: _asDate(json['startDate']),
      endDate: _asDate(json['endDate']),
      preferences: _asStringList(json['preferences']),
      travelNotes: _asString(json['travelNotes']),
    );
  }

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
      'startDate': startDate.toIso8601String().split('T').first,
      'endDate': endDate.toIso8601String().split('T').first,
      'preferences': preferences,
      'travelNotes': travelNotes,
    };
  }

  static String _asString(Object? value) => value?.toString() ?? '';

  static double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime _asDate(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }

  static List<String> _asStringList(Object? value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
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
