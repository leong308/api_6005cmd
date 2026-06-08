import 'package:api_6005cmd/features/api_demo/model/api_endpoint_model.dart';

class ApiDemoDataSource {
  const ApiDemoDataSource();

  List<ApiEndpointModel> endpoints() {
    return const [
      ApiEndpointModel(
        method: 'POST',
        path: '/trips',
        description: 'Create a new trip record.',
        group: EndpointGroup.tripCrud,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/trips',
        description: 'Fetch all trips.',
        group: EndpointGroup.tripCrud,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/trips/:id',
        description: 'Fetch single trip by ID.',
        group: EndpointGroup.tripCrud,
      ),
      ApiEndpointModel(
        method: 'PUT',
        path: '/trips/:id',
        description: 'Update selected trip.',
        group: EndpointGroup.tripCrud,
      ),
      ApiEndpointModel(
        method: 'DELETE',
        path: '/trips/:id',
        description: 'Delete selected trip.',
        group: EndpointGroup.tripCrud,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/trips/:id/weather',
        description:
            'Weather lookup by trip coordinates with provider fallback.',
        group: EndpointGroup.externalData,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/trips/:id/weather/forecast',
        description:
            'Daily forecast for the trip date range with provider fallback.',
        group: EndpointGroup.externalData,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/trips/:id/google-places',
        description: 'Nearby places from Google Places.',
        group: EndpointGroup.externalData,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/trips/:id/recommendations',
        description: 'Live nearby recommendations from Foursquare Places.',
        group: EndpointGroup.externalData,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/trips/:id/country-info',
        description: 'Country details from REST Countries.',
        group: EndpointGroup.externalData,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/external/reverse-geocode',
        description: 'Country lookup by pinned map coordinates.',
        group: EndpointGroup.externalData,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/trips/:id/summary',
        description: 'Combined payload for the Smart Travel Summary page.',
        group: EndpointGroup.combinedOutput,
      ),
      ApiEndpointModel(
        method: 'POST',
        path: '/auth/register',
        description: 'Optional user registration endpoint.',
        group: EndpointGroup.optionalAuth,
        optional: true,
      ),
      ApiEndpointModel(
        method: 'POST',
        path: '/auth/login',
        description: 'Optional JWT login endpoint.',
        group: EndpointGroup.optionalAuth,
        optional: true,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/auth/profile',
        description: 'Optional authenticated user profile endpoint.',
        group: EndpointGroup.optionalAuth,
        optional: true,
      ),
    ];
  }
}
