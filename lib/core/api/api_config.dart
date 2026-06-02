class ApiConfig {
  const ApiConfig._();

  static const String selfApiBaseUrl = String.fromEnvironment(
    'SELF_API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );
  static const String externalProxyBaseUrl = String.fromEnvironment(
    'EXTERNAL_PROXY_BASE_URL',
    defaultValue: 'http://localhost:3000/api/external',
  );

  static const String googlePlacesApiKeyEnv = 'GOOGLE_PLACES_API_KEY';
  static const String foursquareApiKeyEnv = 'FOURSQUARE_API_KEY';

  static const Duration requestTimeout = Duration(seconds: 15);
}
