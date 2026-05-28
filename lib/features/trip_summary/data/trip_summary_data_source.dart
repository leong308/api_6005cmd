import 'package:api_6005cmd/features/trip_list/data/trip_list_data_source.dart';
import 'package:api_6005cmd/features/trip_summary/model/trip_summary_model.dart';

class TripSummaryDataSource {
  TripSummaryDataSource(this.tripDataSource);

  final TripListDataSource tripDataSource;

  Future<TripSummaryModel?> fetchSummary(String tripId) async {
    final trip = await tripDataSource.fetchTripById(tripId);
    if (trip == null) {
      return null;
    }
    await Future<void>.delayed(const Duration(milliseconds: 160));
    final seed = _summarySeedByTrip[tripId] ?? _summarySeedByTrip['trip_001']!;
    return TripSummaryModel(
      trip: trip,
      weather: seed.weather,
      googlePlaces: seed.googlePlaces,
      foursquareRecommendations: seed.foursquareRecommendations,
      countryInfo: seed.countryInfo,
    );
  }
}

class _SummarySeed {
  const _SummarySeed({
    required this.weather,
    required this.googlePlaces,
    required this.foursquareRecommendations,
    required this.countryInfo,
  });

  final WeatherModel weather;
  final List<PlaceModel> googlePlaces;
  final List<RecommendationModel> foursquareRecommendations;
  final CountryInfoModel countryInfo;
}

const Map<String, _SummarySeed> _summarySeedByTrip = {
  'trip_001': _SummarySeed(
    weather: WeatherModel(
      temperature: 27,
      condition: 'Cloudy',
      humidity: 70,
      windSpeed: 3.2,
    ),
    googlePlaces: [
      PlaceModel(
        name: 'Tokyo Tower',
        address: 'Tokyo, Japan',
        rating: 4.5,
        type: 'tourist_attraction',
      ),
      PlaceModel(
        name: 'Shibuya Crossing',
        address: 'Shibuya, Tokyo',
        rating: 4.7,
        type: 'landmark',
      ),
      PlaceModel(
        name: 'Ueno Park',
        address: 'Taito, Tokyo',
        rating: 4.6,
        type: 'park',
      ),
    ],
    foursquareRecommendations: [
      RecommendationModel(
        name: 'Senso-ji Temple',
        category: 'Temple',
        distanceMeters: 3500,
        address: 'Asakusa, Tokyo',
      ),
      RecommendationModel(
        name: 'Tsukiji Market',
        category: 'Market',
        distanceMeters: 4700,
        address: 'Chuo, Tokyo',
      ),
      RecommendationModel(
        name: 'Local Ramen Spot',
        category: 'Restaurant',
        distanceMeters: 1200,
        address: 'Shinjuku, Tokyo',
      ),
    ],
    countryInfo: CountryInfoModel(
      country: 'Japan',
      capital: 'Tokyo',
      currency: 'Japanese Yen',
      languages: ['Japanese'],
      region: 'Asia',
      flag: 'Japan',
    ),
  ),
  'trip_002': _SummarySeed(
    weather: WeatherModel(
      temperature: 31,
      condition: 'Light Rain',
      humidity: 78,
      windSpeed: 2.8,
    ),
    googlePlaces: [
      PlaceModel(
        name: 'Wat Arun',
        address: 'Bangkok, Thailand',
        rating: 4.6,
        type: 'temple',
      ),
      PlaceModel(
        name: 'Chatuchak Market',
        address: 'Bangkok, Thailand',
        rating: 4.4,
        type: 'market',
      ),
      PlaceModel(
        name: 'ICONSIAM',
        address: 'Bangkok, Thailand',
        rating: 4.5,
        type: 'shopping_mall',
      ),
    ],
    foursquareRecommendations: [
      RecommendationModel(
        name: 'Yaowarat Street Food',
        category: 'Food',
        distanceMeters: 1900,
        address: 'Chinatown, Bangkok',
      ),
      RecommendationModel(
        name: 'Siam Night Market',
        category: 'Shopping',
        distanceMeters: 2300,
        address: 'Pathum Wan, Bangkok',
      ),
    ],
    countryInfo: CountryInfoModel(
      country: 'Thailand',
      capital: 'Bangkok',
      currency: 'Thai Baht',
      languages: ['Thai'],
      region: 'Asia',
      flag: 'Thailand',
    ),
  ),
  'trip_003': _SummarySeed(
    weather: WeatherModel(
      temperature: 24,
      condition: 'Clear',
      humidity: 60,
      windSpeed: 2.1,
    ),
    googlePlaces: [
      PlaceModel(
        name: 'Gyeongbokgung Palace',
        address: 'Seoul, South Korea',
        rating: 4.7,
        type: 'palace',
      ),
      PlaceModel(
        name: 'N Seoul Tower',
        address: 'Seoul, South Korea',
        rating: 4.6,
        type: 'landmark',
      ),
      PlaceModel(
        name: 'Lotte World',
        address: 'Seoul, South Korea',
        rating: 4.5,
        type: 'family_attraction',
      ),
    ],
    foursquareRecommendations: [
      RecommendationModel(
        name: 'Bukchon Hanok Village',
        category: 'Culture',
        distanceMeters: 2100,
        address: 'Jongno, Seoul',
      ),
      RecommendationModel(
        name: 'COEX Aquarium',
        category: 'Family',
        distanceMeters: 5400,
        address: 'Gangnam, Seoul',
      ),
    ],
    countryInfo: CountryInfoModel(
      country: 'South Korea',
      capital: 'Seoul',
      currency: 'South Korean Won',
      languages: ['Korean'],
      region: 'Asia',
      flag: 'South Korea',
    ),
  ),
};
