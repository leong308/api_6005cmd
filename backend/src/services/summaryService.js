const { getTripById } = require("../data/store");
const countryService = require("./countryService");
const { HttpError } = require("../lib/http");

/**
 * Orchestrates external API calls asynchronously for a specific trip.
 * Protects against partial failures using individual isolated blocks.
 */
async function generateSummary(tripId, host, scheme) {
  const trip = getTripById(tripId);
  if (!trip) {
    throw new HttpError(404, "Trip not found.");
  }

  const { latitude, longitude, destinationCountry, preferences } = trip;
  const preference = Array.isArray(preferences) && preferences.length > 0 ? preferences[0] : "family";

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
      console.error(`Graceful partial failure: OpenWeatherMap failed - ${err.message}`);
      return null;
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

  const recommendationsPromise = (async () => {
    try {
      const response = await fetch(
        `${scheme}://${host}/api/external/recommendations?lat=${latitude}&lng=${longitude}&preference=${preference}`
      );
      if (!response.ok) {
        throw new Error(`Proxy recommendations returned status ${response.status}`);
      }
      const json = await response.json();
      return json.data;
    } catch (err) {
      console.error(`Graceful partial failure: Foursquare failed - ${err.message}`);
      return null;
    }
  })();

  const countryInfoPromise = (async () => {
    try {
      const data = await countryService.fetchCountryData(destinationCountry);
      return data;
    } catch (err) {
      console.error(`Graceful partial failure: Country service failed - ${err.message}`);
      return null;
    }
  })();

  // Fetch all resources concurrently
  const [weather, googlePlaces, recommendations, countryInfo] = await Promise.all([
    weatherPromise,
    googlePlacesPromise,
    recommendationsPromise,
    countryInfoPromise,
  ]);

  return {
    trip,
    weather,
    googlePlaces,
    recommendations,
    countryInfo,
  };
}

module.exports = {
  generateSummary,
};
