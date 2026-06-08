import 'package:api_6005cmd/features/api_demo/model/api_endpoint_model.dart';

class ApiDemoDataSource {
  const ApiDemoDataSource();

  List<ApiEndpointModel> endpoints() {
    return const [
      ApiEndpointModel(
        method: 'GET',
        path: '/health',
        description: 'Backend health check.',
        group: EndpointGroup.system,
      ),
      ApiEndpointModel(
        method: 'POST',
        path: '/trips',
        description: 'Create a trip record.',
        group: EndpointGroup.tripCrud,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/trips',
        description: 'Fetch all authenticated user trips.',
        group: EndpointGroup.tripCrud,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/trips/:id',
        description: 'Fetch one trip by ID.',
        group: EndpointGroup.tripCrud,
      ),
      ApiEndpointModel(
        method: 'PUT',
        path: '/trips/:id',
        description: 'Update a selected trip.',
        group: EndpointGroup.tripCrud,
      ),
      ApiEndpointModel(
        method: 'DELETE',
        path: '/trips/:id',
        description: 'Delete a selected trip and related weather cache.',
        group: EndpointGroup.tripCrud,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/trips/:id/weather',
        description:
            'Trip current weather with Open-Meteo, OpenWeather, and MET Norway fallback. Use refresh=true to bypass cache.',
        group: EndpointGroup.externalData,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/trips/:id/weather/forecast',
        description:
            'Trip daily forecast with provider fallback. Use refresh=true to bypass cache.',
        group: EndpointGroup.externalData,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/trips/:id/google-places',
        description: 'Trip nearby Google Places demo payload.',
        group: EndpointGroup.externalData,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/trips/:id/recommendations',
        description:
            'Grouped live recommendations from Foursquare with Geoapify fallback. Supports limits and refresh=true.',
        group: EndpointGroup.externalData,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/trips/:id/agenda',
        description:
            'Timed trip agenda from weather and recommendation data. Returns insufficient data instead of placeholders.',
        group: EndpointGroup.externalData,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/trips/:id/country-info',
        description: 'Country details for the trip destination.',
        group: EndpointGroup.externalData,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/external/weather',
        description:
            'External current weather proxy by lat/lng. Supports refresh=true.',
        group: EndpointGroup.externalData,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/external/weather/forecast',
        description:
            'External daily forecast proxy by lat/lng and date range. Supports refresh=true.',
        group: EndpointGroup.externalData,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/external/google-places',
        description: 'Provider-shaped Google Places demo proxy.',
        group: EndpointGroup.externalData,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/external/recommendations',
        description:
            'External recommendations proxy with Foursquare and Geoapify fallback. Supports refresh=true.',
        group: EndpointGroup.externalData,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/external/route',
        description: 'Google Routes proxy for walking or vehicle routes.',
        group: EndpointGroup.externalData,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/external/walking-route',
        description: 'Alias for the route proxy with walking route support.',
        group: EndpointGroup.externalData,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/external/country-info',
        description: 'Country details by country query parameter.',
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
        path: '/countries/:name',
        description: 'REST Countries lookup through the countries router.',
        group: EndpointGroup.externalData,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/trips/:id/summary',
        description:
            'Combined Smart Travel Summary payload. Refresh External Data sends refresh=true and replaces Mongo cache with fresh results.',
        group: EndpointGroup.combinedOutput,
      ),
      ApiEndpointModel(
        method: 'POST',
        path: '/auth/register',
        description: 'Register a user and send verification email.',
        group: EndpointGroup.optionalAuth,
        optional: true,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/auth/verify-email',
        description: 'Verify an email address by token.',
        group: EndpointGroup.optionalAuth,
        optional: true,
      ),
      ApiEndpointModel(
        method: 'POST',
        path: '/auth/resend-verification',
        description: 'Resend the email verification link.',
        group: EndpointGroup.optionalAuth,
        optional: true,
      ),
      ApiEndpointModel(
        method: 'POST',
        path: '/auth/forgot-password',
        description: 'Request a password reset link.',
        group: EndpointGroup.optionalAuth,
        optional: true,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/auth/reset-password',
        description: 'Open the backend-hosted password reset form.',
        group: EndpointGroup.optionalAuth,
        optional: true,
      ),
      ApiEndpointModel(
        method: 'POST',
        path: '/auth/reset-password',
        description: 'Submit a password reset token and new password.',
        group: EndpointGroup.optionalAuth,
        optional: true,
      ),
      ApiEndpointModel(
        method: 'POST',
        path: '/auth/login',
        description: 'Log in and receive a JWT.',
        group: EndpointGroup.optionalAuth,
        optional: true,
      ),
      ApiEndpointModel(
        method: 'GET',
        path: '/auth/profile',
        description: 'Fetch the authenticated user profile.',
        group: EndpointGroup.optionalAuth,
        optional: true,
      ),
      ApiEndpointModel(
        method: 'POST',
        path: '/auth/complete-tour',
        description: 'Mark the first-login app tour as completed.',
        group: EndpointGroup.optionalAuth,
        optional: true,
      ),
    ];
  }
}
