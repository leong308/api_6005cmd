import 'package:api_6005cmd/features/trip_list/model/trip_list_item_model.dart';

class WeatherModel {
  const WeatherModel({
    required this.temperature,
    required this.condition,
    required this.humidity,
    required this.windSpeed,
  });

  final num temperature;
  final String condition;
  final int humidity;
  final num windSpeed;

  factory WeatherModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const WeatherModel(
        temperature: 0,
        condition: 'Unavailable',
        humidity: 0,
        windSpeed: 0,
      );
    }

    return WeatherModel(
      temperature: _asNum(json['temperature']),
      condition: _asString(json['condition'], fallback: 'Unavailable'),
      humidity: _asInt(json['humidity']),
      windSpeed: _asNum(json['windSpeed']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'condition': condition,
      'humidity': humidity,
      'windSpeed': windSpeed,
    };
  }
}

class PlaceModel {
  const PlaceModel({
    required this.name,
    required this.address,
    required this.rating,
    required this.type,
  });

  final String name;
  final String address;
  final num rating;
  final String type;

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      name: _asString(json['name'], fallback: 'Unnamed place'),
      address: _asString(
        json['address'],
        fallback: _coordinatesLabel(json['coordinates']),
      ),
      rating: _asNum(json['rating']),
      type: _asString(json['type'], fallback: 'place'),
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'address': address, 'rating': rating, 'type': type};
  }
}

class RecommendationModel {
  const RecommendationModel({
    required this.name,
    required this.category,
    required this.distanceMeters,
    required this.address,
  });

  final String name;
  final String category;
  final int distanceMeters;
  final String address;

  factory RecommendationModel.fromJson(Map<String, dynamic> json) {
    return RecommendationModel(
      name: _asString(json['name'], fallback: 'Unnamed recommendation'),
      category: _asString(json['category'], fallback: 'recommendation'),
      distanceMeters: _asInt(json['distanceMeters'] ?? json['distance']),
      address: _asString(
        json['address'],
        fallback: _coordinatesLabel(json['coordinates']),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'distanceMeters': distanceMeters,
      'address': address,
    };
  }
}

class CountryInfoModel {
  const CountryInfoModel({
    required this.country,
    required this.capital,
    required this.currency,
    required this.languages,
    required this.region,
    required this.flag,
    this.countryCode = '',
  });

  final String country;
  final String capital;
  final String currency;
  final List<String> languages;
  final String region;
  final String flag;
  final String countryCode;

  factory CountryInfoModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const CountryInfoModel(
        country: 'Unavailable',
        capital: 'Unavailable',
        currency: 'Unavailable',
        languages: [],
        region: 'Unavailable',
        flag: '',
      );
    }

    return CountryInfoModel(
      country: _asString(json['country'], fallback: 'Unavailable'),
      capital: _asString(json['capital'], fallback: 'Unavailable'),
      currency: _asString(json['currency'], fallback: 'Unavailable'),
      languages: _asStringList(json['languages']),
      region: _asString(json['region'], fallback: 'Unavailable'),
      flag: _asString(json['flag']),
      countryCode: _asString(json['countryCode']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'country': country,
      'capital': capital,
      'currency': currency,
      'languages': languages,
      'region': region,
      'flag': flag,
      'countryCode': countryCode,
    };
  }
}

class TripSummaryModel {
  const TripSummaryModel({
    required this.trip,
    required this.weather,
    required this.googlePlaces,
    required this.foursquareRecommendations,
    required this.countryInfo,
  });

  final TripListItemModel trip;
  final WeatherModel weather;
  final List<PlaceModel> googlePlaces;
  final List<RecommendationModel> foursquareRecommendations;
  final CountryInfoModel countryInfo;

  factory TripSummaryModel.fromJson(Map<String, dynamic> json) {
    return TripSummaryModel(
      trip: TripListItemModel.fromJson(_asMap(json['trip'])),
      weather: WeatherModel.fromJson(_asNullableMap(json['weather'])),
      googlePlaces: _asModelList(json['googlePlaces'], PlaceModel.fromJson),
      foursquareRecommendations: _asModelList(
        json['recommendations'] ?? json['foursquareRecommendations'],
        RecommendationModel.fromJson,
      ),
      countryInfo: CountryInfoModel.fromJson(
        _asNullableMap(json['countryInfo']),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trip': trip.toJson(),
      'weather': weather.toJson(),
      'googlePlaces': googlePlaces.map((e) => e.toJson()).toList(),
      'foursquareRecommendations': foursquareRecommendations
          .map((e) => e.toJson())
          .toList(),
      'countryInfo': countryInfo.toJson(),
    };
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

Map<String, dynamic>? _asNullableMap(Object? value) {
  if (value == null) {
    return null;
  }
  return _asMap(value);
}

List<T> _asModelList<T>(
  Object? value,
  T Function(Map<String, dynamic> json) fromJson,
) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Object>()
      .map(_asMap)
      .where((json) => json.isNotEmpty)
      .map(fromJson)
      .toList();
}

List<String> _asStringList(Object? value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  return const [];
}

String _asString(Object? value, {String fallback = ''}) {
  final text = value?.toString() ?? '';
  return text.isEmpty ? fallback : text;
}

num _asNum(Object? value) {
  if (value is num) {
    return value;
  }
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _coordinatesLabel(Object? value) {
  final coordinates = _asNullableMap(value);
  if (coordinates == null) {
    return 'Address unavailable';
  }
  final latitude = coordinates['latitude'];
  final longitude = coordinates['longitude'];
  if (latitude == null || longitude == null) {
    return 'Address unavailable';
  }
  return 'Coordinates: $latitude, $longitude';
}
