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

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'rating': rating,
      'type': type,
    };
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

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'distance': distanceMeters,
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
  });

  final String country;
  final String capital;
  final String currency;
  final List<String> languages;
  final String region;
  final String flag;

  Map<String, dynamic> toJson() {
    return {
      'country': country,
      'capital': capital,
      'currency': currency,
      'languages': languages,
      'region': region,
      'flag': flag,
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

  Map<String, dynamic> toJson() {
    return {
      'trip': trip.toJson(),
      'weather': weather.toJson(),
      'googlePlaces': googlePlaces.map((e) => e.toJson()).toList(),
      'foursquareRecommendations':
          foursquareRecommendations.map((e) => e.toJson()).toList(),
      'countryInfo': countryInfo.toJson(),
    };
  }
}
