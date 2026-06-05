/**
 * Trip summary aggregation service.
 *
 * This file combines local trip data with weather, forecast, places,
 * recommendation, country, and agenda modules into one response for
 * `GET /api/trips/:id/summary`.
 */
const { getTripById } = require("../data/store");
const agendaService = require("./agendaService");
const countryService = require("./countryService");
const foursquareService = require("./foursquareService");
const reverseGeocodeService = require("./reverseGeocodeService");
const weatherService = require("./weatherService");
const { HttpError } = require("../lib/http");

/**
 * Orchestrates external API calls asynchronously for a specific trip.
 * Protects against partial failures using individual isolated blocks.
 */
async function generateSummary(tripId, host, scheme, options = {}) {
  const trip = getTripById(tripId);
  if (!trip) {
    throw new HttpError(404, "Trip not found.");
  }

  const { latitude, longitude, destinationCountry, preferences } = trip;
  const recommendationLimit = options.recommendationLimit ?? 5;
  const recommendationLimits = options.recommendationLimits ?? {};
  const resolvedDestinationCountryPromise = resolveDestinationCountry(trip);
  const preference =
    Array.isArray(preferences) && preferences.length > 0
      ? preferences[0]
      : "family";

  // Individual isolated protection blocks to allow graceful partial failures
  const weatherPromise = (async () => {
    try {
      const response = await fetch(`${scheme}://${host}/api/external/weather?lat=${latitude}&lng=${longitude}`);
      if (!response.ok) {
        throw new Error(`Proxy weather returned status ${response.status}`);
      }
      const json = await response.json();
      return json.data;
    } catch (err) {
      console.error(`Graceful partial failure: Open-Meteo failed - ${err.message}`);
      return null;
    }
  })();

  const dailyWeatherForecastPromise = (async () => {
    try {
      return await weatherService.fetchDailyForecast(
        latitude,
        longitude,
        trip.startDate,
        trip.endDate,
      );
    } catch (err) {
      console.error(`Graceful partial failure: Open-Meteo daily forecast failed - ${err.message}`);
      return buildUnavailableDailyWeatherForecast(trip, err.message);
    }
  })();

  const googlePlacesPromise = (async () => {
    try {
      const response = await fetch(
        `${scheme}://${host}/api/external/google-places?lat=${latitude}&lng=${longitude}&preference=${preference}`
      );
      if (!response.ok) {
        throw new Error(`Proxy places returned status ${response.status}`);
      }
      const json = await response.json();
      return json.data;
    } catch (err) {
      console.error(`Graceful partial failure: Google Places failed - ${err.message}`);
      return null;
    }
  })();

  const recommendationGroupsPromise = (async () => {
    try {
      return await foursquareService.fetchRecommendationGroups({
        latitude,
        longitude,
        preferences,
        limit: recommendationLimit,
        limitsByPreference: recommendationLimits,
      });
    } catch (err) {
      console.error(`Graceful partial failure: Foursquare failed - ${err.message}`);
      return [];
    }
  })();

  const countryInfoPromise = (async () => {
    try {
      const resolvedDestinationCountry = await resolvedDestinationCountryPromise;
      const data = await countryService.fetchCountryData(
        resolvedDestinationCountry,
      );
      return data;
    } catch (err) {
      console.error(`Graceful partial failure: Country service failed - ${err.message}`);
      return null;
    }
  })();

  // Fetch all resources concurrently
  const [
    weather,
    dailyWeatherForecast,
    googlePlaces,
    recommendationGroups,
    countryInfo,
    resolvedDestinationCountry,
  ] = await Promise.all([
    weatherPromise,
    dailyWeatherForecastPromise,
    googlePlacesPromise,
    recommendationGroupsPromise,
    countryInfoPromise,
    resolvedDestinationCountryPromise,
  ]);
  const recommendations = recommendationGroups.flatMap(
    (group) => group.recommendations,
  );
  const responseTrip =
    String(destinationCountry ?? "").trim().length > 0 ||
    resolvedDestinationCountry.length === 0
      ? trip
      : { ...trip, destinationCountry: resolvedDestinationCountry };
  let tripAgenda;
  try {
    tripAgenda = await agendaService.buildTimedTripAgenda({
      trip: responseTrip,
      dailyWeatherForecast,
      recommendationGroups,
      availabilityDays: options.availabilityDays,
      routeMapDays: options.routeMapDays,
      routeMapDayIndexes: options.routeMapDayIndexes,
    });
  } catch (err) {
    console.error(`Graceful partial failure: Timed agenda failed - ${err.message}`);
    tripAgenda = await agendaService.buildTripAgenda({
      trip: responseTrip,
      dailyWeatherForecast,
      recommendationGroups,
      availabilityDays: options.availabilityDays,
      routeMapDays: options.routeMapDays,
      routeMapDayIndexes: options.routeMapDayIndexes,
    });
  }

  return {
    trip: responseTrip,
    weather,
    dailyWeatherForecast,
    googlePlaces,
    recommendations,
    recommendationGroups,
    recommendationLimit,
    recommendationLimits: Object.fromEntries(
      recommendationGroups.map((group) => [group.preference, group.limit]),
    ),
    countryInfo,
    tripAgenda,
    agenda: tripAgenda,
  };
}

module.exports = {
  generateSummary,
};

async function resolveDestinationCountry(trip) {
  const storedCountry = String(trip.destinationCountry ?? "").trim();
  if (storedCountry.length > 0) {
    return storedCountry;
  }

  try {
    const result = await reverseGeocodeService.reverseGeocode(
      Number(trip.latitude),
      Number(trip.longitude),
    );
    return String(result.country ?? "").trim();
  } catch (err) {
    console.error(`Graceful partial failure: Reverse geocoding failed - ${err.message}`);
    return "";
  }
}

function buildUnavailableDailyWeatherForecast(trip, message) {
  return {
    latitude: trip.latitude,
    longitude: trip.longitude,
    startDate: trip.startDate,
    endDate: trip.endDate,
    timezone: "",
    units: "metric",
    message:
      message ||
      "Daily forecast unavailable for this trip date range.",
    daily: [],
  };
}
