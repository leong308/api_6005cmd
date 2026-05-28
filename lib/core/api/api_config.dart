class ApiConfig {
  const ApiConfig._();

  static const String selfApiBaseUrl = 'http://localhost:3000/api';
  static const String externalProxyBaseUrl =
      'http://localhost:3000/api/external';

  static const String openWeatherApiKeyEnv = 'OPENWEATHER_API_KEY';
  static const String googlePlacesApiKeyEnv = 'GOOGLE_PLACES_API_KEY';
  static const String foursquareApiKeyEnv = 'FOURSQUARE_API_KEY';

  static const Duration requestTimeout = Duration(seconds: 15);
}
