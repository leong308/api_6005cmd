/**
 * External provider proxy routes.
 *
 * This file exposes backend endpoints that call third-party services or return
 * provider-shaped mock data. Keeping these calls in the backend protects keys,
 * centralizes validation, and gives Flutter a stable API shape.
 */
const express = require("express");
const { HttpError } = require("../lib/http");
const { authMiddleware } = require("../middleware/authMiddleware");
const countryService = require("../services/countryService");
const foursquareService = require("../services/foursquareService");
const reverseGeocodeService = require("../services/reverseGeocodeService");
const routeService = require("../services/routeService");
const weatherService = require("../services/weatherService");

const externalRouter = express.Router();

// Provider proxy routes can consume paid quotas, so require the same JWT used
// by the authenticated Flutter workspace.
externalRouter.use(authMiddleware);

/**
 * Ensures the coordinates input is valid.
 */
function ensureCoordinates(req) {
  const latitude = Number(req.query.lat);
  const longitude = Number(req.query.lng);

  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
    throw new HttpError(
      400,
      "Query param lat must be a valid number between -90 and 90.",
    );
  }
  if (!Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    throw new HttpError(
      400,
      "Query param lng must be a valid number between -180 and 180.",
    );
  }

  return { latitude, longitude };
}

/**
 * Ensures the date range input is valid.
 */
function ensureDateRange(req) {
  const startDate = String(req.query.startDate ?? req.query.start_date ?? "").trim();
  const endDate = String(req.query.endDate ?? req.query.end_date ?? "").trim();

  if (!startDate || !endDate) {
    throw new HttpError(
      400,
      "Query params startDate and endDate are required in YYYY-MM-DD format.",
    );
  }

  return { startDate, endDate };
}

/**
 * Ensures the route coordinates input is valid.
 */
function ensureRouteCoordinates(req) {
  const fromLatitude = Number(req.query.fromLat);
  const fromLongitude = Number(req.query.fromLng);
  const toLatitude = Number(req.query.toLat);
  const toLongitude = Number(req.query.toLng);

  if (
    !isValidLatitude(fromLatitude) ||
    !isValidLongitude(fromLongitude) ||
    !isValidLatitude(toLatitude) ||
    !isValidLongitude(toLongitude)
  ) {
    throw new HttpError(
      400,
      "Route coordinates must be valid latitude/longitude values.",
    );
  }

  return {
    fromLatitude,
    fromLongitude,
    toLatitude,
    toLongitude,
  };
}

function isValidLatitude(value) {
  return Number.isFinite(value) && value >= -90 && value <= 90;
}

function isValidLongitude(value) {
  return Number.isFinite(value) && value >= -180 && value <= 180;
}

/**
 * Handles GET /weather requests for the external API.
 */
externalRouter.get("/weather", async (req, res, next) => {
  try {
    const { latitude, longitude } = ensureCoordinates(req);
    const data = await weatherService.fetchCurrentWeather(latitude, longitude, {
      forceRefresh: parseBooleanQuery(
        req.query.refresh ?? req.query.forceRefresh,
      ),
    });

    return res.json({
      success: true,
      provider: data.provider ?? "weather-fallback-chain",
      data,
    });
  } catch (error) {
    return next(error);
  }
});

/**
 * Handles GET /weather/forecast requests for the external API.
 */
externalRouter.get("/weather/forecast", async (req, res, next) => {
  try {
    const { latitude, longitude } = ensureCoordinates(req);
    const { startDate, endDate } = ensureDateRange(req);
    const data = await weatherService.fetchDailyForecast(
      latitude,
      longitude,
      startDate,
      endDate,
      {
        forceRefresh: parseBooleanQuery(
          req.query.refresh ?? req.query.forceRefresh,
        ),
      },
    );

    return res.json({
      success: true,
      provider: data.provider ?? "weather-fallback-chain",
      data,
    });
  } catch (error) {
    return next(error);
  }
});

/**
 * Supports the handle route request backend flow.
 */
async function handleRouteRequest(req, res, next) {
  try {
    const coordinates = ensureRouteCoordinates(req);
    const data = await routeService.fetchRoute({
      ...coordinates,
      mode: req.query.mode,
    });

    return res.json({
      success: true,
      provider: data.provider,
      data,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Handles GET /route requests for the external API.
 */
externalRouter.get("/route", handleRouteRequest);
/**
 * Handles GET /walking-route requests for the external API.
 */
externalRouter.get("/walking-route", handleRouteRequest);

/**
 * Handles GET /google-places requests for the external API.
 */
externalRouter.get("/google-places", (req, res) => {
  const { latitude, longitude } = ensureCoordinates(req);
  const preference = String(req.query.preference ?? "culture");

  res.json({
    success: true,
    provider: "mock-google-places-proxy",
    data: [
      {
        name: "City Landmark",
        rating: 4.5,
        type: preference,
        coordinates: { latitude, longitude },
      },
      {
        name: "Local Hotspot",
        rating: 4.3,
        type: "tourist_attraction",
        coordinates: { latitude, longitude },
      },
    ],
  });
});

/**
 * Handles GET /recommendations requests for the external API.
 */
externalRouter.get("/recommendations", async (req, res, next) => {
  try {
    const { latitude, longitude } = ensureCoordinates(req);
    const preference = String(req.query.preference ?? "family");
    const preferences = parsePreferenceList(req.query.preferences);
    const limit = Number(req.query.limit ?? undefined);
    const limitsByPreference = parseRecommendationLimits(
      req.query.recommendationLimits ?? req.query.limits,
    );
    const forceRefresh = parseBooleanQuery(
      req.query.refresh ?? req.query.forceRefresh,
    );
    const data = preferences.length > 0
      ? await foursquareService.fetchRecommendationGroups({
          latitude,
          longitude,
          preferences,
          limit,
          limitsByPreference,
          forceRefresh,
        })
      : await foursquareService.fetchRecommendations({
          latitude,
          longitude,
          preference,
          limit,
          forceRefresh,
        });

    return res.json({
      success: true,
      provider: "foursquare-with-geoapify-fallback",
      data,
    });
  } catch (error) {
    return next(error);
  }
});

/**
 * Parses the preference list value into the backend format.
 */
function parsePreferenceList(value) {
  if (Array.isArray(value)) {
    return value.flatMap(parsePreferenceList);
  }
  return String(value ?? "")
    .split(",")
    .map((preference) => preference.trim())
    .filter((preference) => preference.length > 0);
}

/**
 * Parses the recommendation limit value into the backend format.
 */
function parseRecommendationLimit(value) {
  const parsed = Number(value);
  return [3, 5, 10].includes(parsed) ? parsed : 5;
}

/**
 * Parses the boolean query value into the backend format.
 */
function parseBooleanQuery(value) {
  return ["1", "true", "yes", "force"].includes(
    String(value ?? "").trim().toLowerCase(),
  );
}

/**
 * Parses the recommendation limits value into the backend format.
 */
function parseRecommendationLimits(value) {
  if (Array.isArray(value)) {
    return value.reduce(
      (limits, item) => ({ ...limits, ...parseRecommendationLimits(item) }),
      {},
    );
  }

  return String(value ?? "")
    .split(",")
    .map((pair) => pair.trim())
    .filter((pair) => pair.length > 0)
    .reduce((limits, pair) => {
      const [rawPreference, rawLimit] = pair.split(":");
      const preference = String(rawPreference ?? "").trim().toLowerCase();
      if (preference.length === 0) {
        return limits;
      }
      return {
        ...limits,
        [preference]: parseRecommendationLimit(rawLimit),
      };
    }, {});
}

/**
 * Handles GET /country-info requests for the external API.
 */
externalRouter.get("/country-info", async (req, res, next) => {
  try {
    const country = String(req.query.country ?? "").trim();
    if (!country) {
      throw new HttpError(400, "Query param country is required.");
    }

    const countryData = await countryService.fetchCountryData(country);

    return res.json({
      success: true,
      provider: "rest-countries",
      data: countryData,
    });
  } catch (error) {
    return next(error);
  }
});

/**
 * Handles GET /reverse-geocode requests for the external API.
 */
externalRouter.get("/reverse-geocode", async (req, res, next) => {
  try {
    const { latitude, longitude } = ensureCoordinates(req);
    const data = await reverseGeocodeService.reverseGeocode(latitude, longitude);

    return res.json({
      success: true,
      provider: data.source || "geoapify-with-nominatim-fallback",
      data,
    });
  } catch (error) {
    return next(error);
  }
});

module.exports = { externalRouter };

