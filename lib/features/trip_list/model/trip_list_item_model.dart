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
      id: _asRequiredString(json['id'], 'id'),
      destinationName: _asRequiredString(
        json['destinationName'],
        'destinationName',
      ),
      destinationCountry: _asRequiredString(
        json['destinationCountry'],
        'destinationCountry',
      ),
      latitude: _asDouble(json['latitude'], 'latitude'),
      longitude: _asDouble(json['longitude'], 'longitude'),
      startDate: _asDate(json['startDate'], 'startDate'),
      endDate: _asDate(json['endDate'], 'endDate'),
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

  static String _asRequiredString(Object? value, String fieldName) {
    final parsed = _asString(value).trim();
    if (parsed.isEmpty) {
      throw FormatException('Trip field "$fieldName" is missing.');
    }
    return parsed;
  }

  static double _asDouble(Object? value, String fieldName) {
    if (value is num) {
      final parsed = value.toDouble();
      if (parsed.isFinite) {
        return parsed;
      }
    }
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed == null || !parsed.isFinite) {
      throw FormatException('Trip field "$fieldName" is not a number.');
    }
    return parsed;
  }

  static DateTime _asDate(Object? value, String fieldName) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      throw FormatException('Trip field "$fieldName" is not a valid date.');
    }
    return parsed;
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
