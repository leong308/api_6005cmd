import 'package:api_6005cmd/features/trip_list/model/trip_list_item_model.dart';

class WeatherModel {
  const WeatherModel({
    required this.temperature,
    required this.condition,
    required this.humidity,
    required this.windSpeed,
    this.feelsLike,
    this.pressure,
    this.observedAt = '',
    this.cityName = '',
    this.countryCode = '',
    this.iconCode = '',
    this.units = 'metric',
  });

  final num temperature;
  final String condition;
  final int humidity;
  final num windSpeed;
  final num? feelsLike;
  final int? pressure;
  final String observedAt;
  final String cityName;
  final String countryCode;
  final String iconCode;
  final String units;

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
      feelsLike: _asNullableNum(json['feelsLike']),
      pressure: _asNullableInt(json['pressure']),
      observedAt: _asString(json['observedAt']),
      cityName: _asString(json['cityName']),
      countryCode: _asString(json['countryCode']),
      iconCode: _asString(json['iconCode']),
      units: _asString(json['units'], fallback: 'metric'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'condition': condition,
      'humidity': humidity,
      'windSpeed': windSpeed,
      'feelsLike': feelsLike,
      'pressure': pressure,
      'observedAt': observedAt,
      'cityName': cityName,
      'countryCode': countryCode,
      'iconCode': iconCode,
      'units': units,
    };
  }
}

class DailyWeatherForecastModel {
  const DailyWeatherForecastModel({
    required this.startDate,
    required this.endDate,
    required this.timezone,
    required this.units,
    required this.message,
    required this.daily,
  });

  final String startDate;
  final String endDate;
  final String timezone;
  final String units;
  final String message;
  final List<DailyWeatherForecastDayModel> daily;

  factory DailyWeatherForecastModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const DailyWeatherForecastModel(
        startDate: '',
        endDate: '',
        timezone: '',
        units: 'metric',
        message: '',
        daily: [],
      );
    }

    return DailyWeatherForecastModel(
      startDate: _asString(json['startDate']),
      endDate: _asString(json['endDate']),
      timezone: _asString(json['timezone']),
      units: _asString(json['units'], fallback: 'metric'),
      message: _asString(json['message']),
      daily: _asModelList(json['daily'], DailyWeatherForecastDayModel.fromJson),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startDate': startDate,
      'endDate': endDate,
      'timezone': timezone,
      'units': units,
      'message': message,
      'daily': daily.map((day) => day.toJson()).toList(),
    };
  }
}

class DailyWeatherForecastDayModel {
  const DailyWeatherForecastDayModel({
    required this.date,
    required this.condition,
    required this.temperatureMax,
    required this.temperatureMin,
    required this.windSpeedMax,
    this.conditionMain = '',
    this.iconCode = '',
    this.apparentTemperatureMax,
    this.apparentTemperatureMin,
    this.precipitationSum,
    this.precipitationProbabilityMax,
  });

  final String date;
  final String condition;
  final String conditionMain;
  final String iconCode;
  final num temperatureMax;
  final num temperatureMin;
  final num windSpeedMax;
  final num? apparentTemperatureMax;
  final num? apparentTemperatureMin;
  final num? precipitationSum;
  final num? precipitationProbabilityMax;

  factory DailyWeatherForecastDayModel.fromJson(Map<String, dynamic> json) {
    return DailyWeatherForecastDayModel(
      date: _asString(json['date']),
      condition: _asString(json['condition'], fallback: 'Unavailable'),
      conditionMain: _asString(json['conditionMain']),
      iconCode: _asString(json['iconCode']),
      temperatureMax: _asNum(json['temperatureMax']),
      temperatureMin: _asNum(json['temperatureMin']),
      apparentTemperatureMax: _asNullableNum(json['apparentTemperatureMax']),
      apparentTemperatureMin: _asNullableNum(json['apparentTemperatureMin']),
      precipitationSum: _asNullableNum(json['precipitationSum']),
      precipitationProbabilityMax: _asNullableNum(
        json['precipitationProbabilityMax'],
      ),
      windSpeedMax: _asNum(json['windSpeedMax']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'condition': condition,
      'conditionMain': conditionMain,
      'iconCode': iconCode,
      'temperatureMax': temperatureMax,
      'temperatureMin': temperatureMin,
      'apparentTemperatureMax': apparentTemperatureMax,
      'apparentTemperatureMin': apparentTemperatureMin,
      'precipitationSum': precipitationSum,
      'precipitationProbabilityMax': precipitationProbabilityMax,
      'windSpeedMax': windSpeedMax,
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
    this.latitude,
    this.longitude,
  });

  final String name;
  final String category;
  final int distanceMeters;
  final String address;
  final double? latitude;
  final double? longitude;

  factory RecommendationModel.fromJson(Map<String, dynamic> json) {
    final coordinates = _asNullableMap(json['coordinates']);
    return RecommendationModel(
      name: _asString(json['name'], fallback: 'Unnamed recommendation'),
      category: _asString(json['category'], fallback: 'recommendation'),
      distanceMeters: _asInt(json['distanceMeters'] ?? json['distance']),
      address: _asString(
        json['address'],
        fallback: _coordinatesLabel(json['coordinates']),
      ),
      latitude: _asNullableDouble(coordinates?['latitude']),
      longitude: _asNullableDouble(coordinates?['longitude']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'distanceMeters': distanceMeters,
      'address': address,
      'coordinates': {'latitude': latitude, 'longitude': longitude},
    };
  }
}

class RecommendationGroupModel {
  const RecommendationGroupModel({
    required this.preference,
    required this.limit,
    required this.recommendations,
  });

  final String preference;
  final int limit;
  final List<RecommendationModel> recommendations;

  factory RecommendationGroupModel.fromJson(Map<String, dynamic> json) {
    return RecommendationGroupModel(
      preference: _asString(json['preference'], fallback: 'family'),
      limit: _asAllowedRecommendationLimit(json['limit']),
      recommendations: _asModelList(
        json['recommendations'] ?? json['data'],
        RecommendationModel.fromJson,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preference': preference,
      'limit': limit,
      'recommendations': recommendations.map((rec) => rec.toJson()).toList(),
    };
  }
}

class WalkingRouteModel {
  const WalkingRouteModel({
    required this.provider,
    required this.mode,
    required this.modeLabel,
    required this.travelMode,
    required this.transitModes,
    required this.distanceMeters,
    required this.estimatedWalkingSeconds,
    required this.path,
  });

  final String provider;
  final String mode;
  final String modeLabel;
  final String travelMode;
  final List<String> transitModes;
  final num distanceMeters;
  final int estimatedWalkingSeconds;
  final List<RoutePointModel> path;

  factory WalkingRouteModel.fromJson(Map<String, dynamic> json) {
    return WalkingRouteModel(
      provider: _asString(json['provider'], fallback: 'google-routes'),
      mode: _asString(json['mode'], fallback: 'walk'),
      modeLabel: _asString(json['modeLabel'], fallback: 'Walk'),
      travelMode: _asString(json['travelMode'], fallback: 'WALK'),
      transitModes: _asStringList(json['transitModes']),
      distanceMeters: _asNum(json['distanceMeters']),
      estimatedWalkingSeconds: _asInt(json['estimatedWalkingSeconds']),
      path: _asModelList(json['path'], RoutePointModel.fromJson),
    );
  }
}

class RoutePointModel {
  const RoutePointModel({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  factory RoutePointModel.fromJson(Map<String, dynamic> json) {
    return RoutePointModel(
      latitude: _asNum(json['latitude']).toDouble(),
      longitude: _asNum(json['longitude']).toDouble(),
    );
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
    required this.dailyWeatherForecast,
    required this.googlePlaces,
    required this.foursquareRecommendations,
    required this.foursquareRecommendationGroups,
    required this.recommendationLimit,
    required this.recommendationLimits,
    required this.countryInfo,
  });

  final TripListItemModel trip;
  final WeatherModel weather;
  final DailyWeatherForecastModel dailyWeatherForecast;
  final List<PlaceModel> googlePlaces;
  final List<RecommendationModel> foursquareRecommendations;
  final List<RecommendationGroupModel> foursquareRecommendationGroups;
  final int recommendationLimit;
  final Map<String, int> recommendationLimits;
  final CountryInfoModel countryInfo;

  factory TripSummaryModel.fromJson(Map<String, dynamic> json) {
    final trip = TripListItemModel.fromJson(_asMap(json['trip']));
    final flatRecommendations = _asModelList(
      json['recommendations'] ?? json['foursquareRecommendations'],
      RecommendationModel.fromJson,
    );
    final recommendationGroups = _asModelList(
      json['recommendationGroups'] ?? json['foursquareRecommendationGroups'],
      RecommendationGroupModel.fromJson,
    );
    return TripSummaryModel(
      trip: trip,
      weather: WeatherModel.fromJson(_asNullableMap(json['weather'])),
      dailyWeatherForecast: DailyWeatherForecastModel.fromJson(
        _asNullableMap(json['dailyWeatherForecast'] ?? json['weatherForecast']),
      ),
      googlePlaces: _asModelList(json['googlePlaces'], PlaceModel.fromJson),
      foursquareRecommendations: flatRecommendations,
      foursquareRecommendationGroups: recommendationGroups.isNotEmpty
          ? recommendationGroups
          : _fallbackRecommendationGroups(trip, flatRecommendations),
      recommendationLimit: _asAllowedRecommendationLimit(
        json['recommendationLimit'],
      ),
      recommendationLimits: _asRecommendationLimits(
        json['recommendationLimits'],
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
      'dailyWeatherForecast': dailyWeatherForecast.toJson(),
      'googlePlaces': googlePlaces.map((e) => e.toJson()).toList(),
      'foursquareRecommendations': foursquareRecommendations
          .map((e) => e.toJson())
          .toList(),
      'foursquareRecommendationGroups': foursquareRecommendationGroups
          .map((group) => group.toJson())
          .toList(),
      'recommendationLimit': recommendationLimit,
      'recommendationLimits': recommendationLimits,
      'countryInfo': countryInfo.toJson(),
    };
  }
}

List<RecommendationGroupModel> _fallbackRecommendationGroups(
  TripListItemModel trip,
  List<RecommendationModel> recommendations,
) {
  if (recommendations.isEmpty) {
    return const [];
  }
  final preference = trip.preferences.isEmpty
      ? 'family'
      : trip.preferences.first;
  return [
    RecommendationGroupModel(
      preference: preference,
      limit: 5,
      recommendations: recommendations,
    ),
  ];
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

num? _asNullableNum(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value;
  }
  return num.tryParse(value.toString());
}

double? _asNullableDouble(Object? value) {
  final parsed = _asNullableNum(value);
  return parsed?.toDouble();
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

int _asAllowedRecommendationLimit(Object? value) {
  final parsed = _asInt(value);
  return const [3, 5, 10].contains(parsed) ? parsed : 5;
}

Map<String, int> _asRecommendationLimits(Object? value) {
  final map = _asNullableMap(value);
  if (map == null) {
    return const {};
  }

  return map.map(
    (key, item) =>
        MapEntry(key.toString(), _asAllowedRecommendationLimit(item)),
  );
}

int? _asNullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value.toString());
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
