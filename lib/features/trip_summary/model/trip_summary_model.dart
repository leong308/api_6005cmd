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

class TripAgendaModel {
  const TripAgendaModel({
    required this.title,
    required this.generatedAt,
    required this.tripDays,
    required this.pattern,
    required this.source,
    required this.days,
    required this.checklist,
  });

  final String title;
  final String generatedAt;
  final int tripDays;
  final String pattern;
  final Map<String, String> source;
  final List<TripAgendaDayModel> days;
  final List<String> checklist;

  factory TripAgendaModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const TripAgendaModel(
        title: 'Weather-aware tour guide',
        generatedAt: '',
        tripDays: 0,
        pattern: '',
        source: {},
        days: [],
        checklist: [],
      );
    }

    return TripAgendaModel(
      title: _asString(json['title'], fallback: 'Weather-aware tour guide'),
      generatedAt: _asString(json['generatedAt']),
      tripDays: _asInt(json['tripDays']),
      pattern: _asString(json['pattern']),
      source: _asStringMap(json['source']),
      days: _asModelList(json['days'], TripAgendaDayModel.fromJson),
      checklist: _asStringList(json['checklist']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'generatedAt': generatedAt,
      'tripDays': tripDays,
      'pattern': pattern,
      'source': source,
      'days': days.map((day) => day.toJson()).toList(),
      'checklist': checklist,
    };
  }
}

class TripAgendaDayModel {
  const TripAgendaDayModel({
    required this.date,
    required this.label,
    required this.theme,
    required this.weatherNote,
    required this.items,
    required this.routeMap,
    this.weather,
  });

  final String date;
  final String label;
  final String theme;
  final String weatherNote;
  final Map<String, dynamic>? weather;
  final List<TripAgendaItemModel> items;
  final AgendaRouteMapModel routeMap;

  factory TripAgendaDayModel.fromJson(Map<String, dynamic> json) {
    return TripAgendaDayModel(
      date: _asString(json['date']),
      label: _asString(json['label']),
      theme: _asString(json['theme'], fallback: 'Local discovery'),
      weatherNote: _asString(json['weatherNote']),
      weather: _asNullableMap(json['weather']),
      items: _asModelList(json['items'], TripAgendaItemModel.fromJson),
      routeMap: AgendaRouteMapModel.fromJson(_asNullableMap(json['routeMap'])),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'label': label,
      'theme': theme,
      'weatherNote': weatherNote,
      'weather': weather,
      'items': items.map((item) => item.toJson()).toList(),
      'routeMap': routeMap.toJson(),
    };
  }
}

class AgendaRouteMapModel {
  const AgendaRouteMapModel({
    required this.mode,
    required this.modeLabel,
    required this.provider,
    required this.routeAvailable,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.legCount,
    required this.stopCount,
    required this.markers,
    required this.legs,
    required this.message,
  });

  final String mode;
  final String modeLabel;
  final String provider;
  final bool routeAvailable;
  final num totalDistanceMeters;
  final int totalDurationSeconds;
  final int legCount;
  final int stopCount;
  final List<AgendaRouteMarkerModel> markers;
  final List<AgendaRouteLegModel> legs;
  final String message;

  factory AgendaRouteMapModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const AgendaRouteMapModel(
        mode: 'walk',
        modeLabel: 'Walk',
        provider: 'unavailable',
        routeAvailable: false,
        totalDistanceMeters: 0,
        totalDurationSeconds: 0,
        legCount: 0,
        stopCount: 0,
        markers: [],
        legs: [],
        message: '',
      );
    }

    return AgendaRouteMapModel(
      mode: _asString(json['mode'], fallback: 'walk'),
      modeLabel: _asString(json['modeLabel'], fallback: 'Walk'),
      provider: _asString(json['provider'], fallback: 'unavailable'),
      routeAvailable: _asBool(json['routeAvailable']),
      totalDistanceMeters: _asNum(json['totalDistanceMeters']),
      totalDurationSeconds: _asInt(json['totalDurationSeconds']),
      legCount: _asInt(json['legCount']),
      stopCount: _asInt(json['stopCount']),
      markers: _asModelList(json['markers'], AgendaRouteMarkerModel.fromJson),
      legs: _asModelList(json['legs'], AgendaRouteLegModel.fromJson),
      message: _asString(json['message']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode,
      'modeLabel': modeLabel,
      'provider': provider,
      'routeAvailable': routeAvailable,
      'totalDistanceMeters': totalDistanceMeters,
      'totalDurationSeconds': totalDurationSeconds,
      'legCount': legCount,
      'stopCount': stopCount,
      'markers': markers.map((marker) => marker.toJson()).toList(),
      'legs': legs.map((leg) => leg.toJson()).toList(),
      'message': message,
    };
  }
}

class AgendaRouteMarkerModel {
  const AgendaRouteMarkerModel({
    required this.label,
    required this.title,
    required this.kind,
    required this.timeOfDay,
    required this.color,
    this.latitude,
    this.longitude,
  });

  final String label;
  final String title;
  final String kind;
  final String timeOfDay;
  final String color;
  final double? latitude;
  final double? longitude;

  factory AgendaRouteMarkerModel.fromJson(Map<String, dynamic> json) {
    final coordinates = _asNullableMap(json['coordinates']);
    return AgendaRouteMarkerModel(
      label: _asString(json['label']),
      title: _asString(json['title']),
      kind: _asString(json['kind']),
      timeOfDay: _asString(json['timeOfDay']),
      color: _asString(json['color']),
      latitude: _asNullableDouble(coordinates?['latitude']),
      longitude: _asNullableDouble(coordinates?['longitude']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'title': title,
      'kind': kind,
      'timeOfDay': timeOfDay,
      'color': color,
      'coordinates': {'latitude': latitude, 'longitude': longitude},
    };
  }
}

class AgendaRouteLegModel {
  const AgendaRouteLegModel({
    required this.legNumber,
    required this.label,
    required this.fromTitle,
    required this.toTitle,
    required this.color,
    required this.provider,
    required this.mode,
    required this.modeLabel,
    required this.travelMode,
    required this.routeAvailable,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.path,
    required this.unavailableReason,
  });

  final int legNumber;
  final String label;
  final String fromTitle;
  final String toTitle;
  final String color;
  final String provider;
  final String mode;
  final String modeLabel;
  final String travelMode;
  final bool routeAvailable;
  final num distanceMeters;
  final int durationSeconds;
  final List<RoutePointModel> path;
  final String unavailableReason;

  factory AgendaRouteLegModel.fromJson(Map<String, dynamic> json) {
    return AgendaRouteLegModel(
      legNumber: _asInt(json['legNumber']),
      label: _asString(json['label']),
      fromTitle: _asString(json['fromTitle']),
      toTitle: _asString(json['toTitle']),
      color: _asString(json['color']),
      provider: _asString(json['provider']),
      mode: _asString(json['mode']),
      modeLabel: _asString(json['modeLabel']),
      travelMode: _asString(json['travelMode']),
      routeAvailable: _asBool(json['routeAvailable']),
      distanceMeters: _asNum(json['distanceMeters']),
      durationSeconds: _asInt(json['durationSeconds']),
      path: _asModelList(json['path'], RoutePointModel.fromJson),
      unavailableReason: _asString(json['unavailableReason']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'legNumber': legNumber,
      'label': label,
      'fromTitle': fromTitle,
      'toTitle': toTitle,
      'color': color,
      'provider': provider,
      'mode': mode,
      'modeLabel': modeLabel,
      'travelMode': travelMode,
      'routeAvailable': routeAvailable,
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
      'path': path
          .map(
            (point) => {
              'latitude': point.latitude,
              'longitude': point.longitude,
            },
          )
          .toList(),
      'unavailableReason': unavailableReason,
    };
  }
}

class TripAgendaItemModel {
  const TripAgendaItemModel({
    required this.slot,
    required this.kind,
    required this.timeOfDay,
    required this.startTime,
    required this.endTime,
    required this.visitWindow,
    required this.title,
    required this.category,
    required this.preference,
    required this.description,
    required this.address,
    required this.distanceMeters,
    required this.availability,
    this.latitude,
    this.longitude,
  });

  final String slot;
  final String kind;
  final String timeOfDay;
  final String startTime;
  final String endTime;
  final String visitWindow;
  final String title;
  final String category;
  final String preference;
  final String description;
  final String address;
  final int distanceMeters;
  final AgendaAvailabilityModel availability;
  final double? latitude;
  final double? longitude;

  factory TripAgendaItemModel.fromJson(Map<String, dynamic> json) {
    final coordinates = _asNullableMap(json['coordinates']);
    return TripAgendaItemModel(
      slot: _asString(json['slot']),
      kind: _asString(json['kind']),
      timeOfDay: _asString(json['timeOfDay']),
      startTime: _asString(json['startTime']),
      endTime: _asString(json['endTime']),
      visitWindow: _asString(json['visitWindow']),
      title: _asString(json['title'], fallback: 'Trip stop'),
      category: _asString(json['category']),
      preference: _asString(json['preference']),
      description: _asString(json['description']),
      address: _asString(json['address']),
      distanceMeters: _asInt(json['distanceMeters']),
      availability: AgendaAvailabilityModel.fromJson(
        _asNullableMap(json['availability']),
      ),
      latitude: _asNullableDouble(coordinates?['latitude']),
      longitude: _asNullableDouble(coordinates?['longitude']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timeOfDay': timeOfDay,
      'slot': slot,
      'kind': kind,
      'startTime': startTime,
      'endTime': endTime,
      'visitWindow': visitWindow,
      'title': title,
      'category': category,
      'preference': preference,
      'description': description,
      'address': address,
      'distanceMeters': distanceMeters,
      'availability': availability.toJson(),
      'coordinates': {'latitude': latitude, 'longitude': longitude},
    };
  }
}

class AgendaAvailabilityModel {
  const AgendaAvailabilityModel({
    required this.openAt,
    required this.verifiedForVisitTime,
    required this.label,
    required this.source,
  });

  final String openAt;
  final bool verifiedForVisitTime;
  final String label;
  final String source;

  factory AgendaAvailabilityModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const AgendaAvailabilityModel(
        openAt: '',
        verifiedForVisitTime: false,
        label: 'Opening-time status unavailable.',
        source: 'unavailable',
      );
    }

    return AgendaAvailabilityModel(
      openAt: _asString(json['openAt']),
      verifiedForVisitTime: _asBool(json['verifiedForVisitTime']),
      label: _asString(
        json['label'],
        fallback: 'Opening-time status unavailable.',
      ),
      source: _asString(json['source']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'openAt': openAt,
      'verifiedForVisitTime': verifiedForVisitTime,
      'label': label,
      'source': source,
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
    required this.tripAgenda,
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
  final TripAgendaModel tripAgenda;

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
      tripAgenda: TripAgendaModel.fromJson(
        _asNullableMap(json['tripAgenda'] ?? json['agenda']),
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
      'tripAgenda': tripAgenda.toJson(),
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

Map<String, String> _asStringMap(Object? value) {
  final map = _asNullableMap(value);
  if (map == null) {
    return const {};
  }

  return map.map((key, item) => MapEntry(key.toString(), item.toString()));
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

bool _asBool(Object? value) {
  if (value is bool) {
    return value;
  }
  final text = value?.toString().toLowerCase();
  return text == 'true' || text == '1' || text == 'yes';
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
