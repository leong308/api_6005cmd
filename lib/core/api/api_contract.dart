class ApiContract {
  const ApiContract._();

  static const String trips = '/trips';
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String profile = '/auth/profile';

  static String tripById(String id) => '$trips/$id';
  static String weather(String tripId) => '${tripById(tripId)}/weather';
  static String weatherForecast(String tripId) =>
      '${tripById(tripId)}/weather/forecast';
  static String googlePlaces(String tripId) =>
      '${tripById(tripId)}/google-places';
  static String recommendations(String tripId) =>
      '${tripById(tripId)}/recommendations';
  static String countryInfo(String tripId) =>
      '${tripById(tripId)}/country-info';
  static String summary(String tripId) => '${tripById(tripId)}/summary';
}
