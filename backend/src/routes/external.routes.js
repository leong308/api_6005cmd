/**
 * External provider proxy routes.
 *
 * This file exposes backend endpoints that call third-party services or return
 * provider-shaped mock data. Keeping these calls in the backend protects keys,
 * centralizes validation, and gives Flutter a stable API shape.
 */
const express = require("express");
const { HttpError } = require("../lib/http");
const countryService = require("../services/countryService");
const foursquareService = require("../services/foursquareService");
const reverseGeocodeService = require("../services/reverseGeocodeService");
const routeService = require("../services/routeService");
const weatherService = require("../services/weatherService");

const externalRouter = express.Router();

function ensureCoordinates(req) {
  const latitude = Number(req.query.lat);
  const longitude = Number(req.query.lng);

  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    throw new HttpError(400, "Query params lat and lng are required numbers.");
  }

  return { latitude, longitude };
}

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

function ensureRouteCoordinates(req) {
  const fromLatitude = Number(req.query.fromLat);
  const fromLongitude = Number(req.query.fromLng);
  const toLatitude = Number(req.query.toLat);
  const toLongitude = Number(req.query.toLng);

  if (
    !Number.isFinite(fromLatitude) ||
    !Number.isFinite(fromLongitude) ||
    !Number.isFinite(toLatitude) ||
    !Number.isFinite(toLongitude)
  ) {
    throw new HttpError(
      400,
      "Query params fromLat, fromLng, toLat, and toLng are required numbers.",
    );
  }

  return {
    fromLatitude,
    fromLongitude,
    toLatitude,
    toLongitude,
  };
}

externalRouter.get("/weather", async (req, res, next) => {
  try {
    const { latitude, longitude } = ensureCoordinates(req);
    const data = await weatherService.fetchCurrentWeather(latitude, longitude);

    return res.json({
      success: true,
      provider: "open-meteo",
      data,
    });
  } catch (error) {
    return next(error);
  }
});

externalRouter.get("/weather/forecast", async (req, res, next) => {
  try {
    const { latitude, longitude } = ensureCoordinates(req);
    const { startDate, endDate } = ensureDateRange(req);
    const data = await weatherService.fetchDailyForecast(
      latitude,
      longitude,
      startDate,
      endDate,
    );

    return res.json({
      success: true,
      provider: "open-meteo",
      data,
    });
  } catch (error) {
    return next(error);
  }
});

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

externalRouter.get("/route", handleRouteRequest);
externalRouter.get("/walking-route", handleRouteRequest);

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

externalRouter.get("/recommendations", async (req, res, next) => {
  try {
    const { latitude, longitude } = ensureCoordinates(req);
    const preference = String(req.query.preference ?? "family");
    const preferences = parsePreferenceList(req.query.preferences);
    const limit = Number(req.query.limit ?? undefined);
    const limitsByPreference = parseRecommendationLimits(
      req.query.recommendationLimits ?? req.query.limits,
    );
    const data = preferences.length > 0
      ? await foursquareService.fetchRecommendationGroups({
          latitude,
          longitude,
          preferences,
          limit,
          limitsByPreference,
        })
      : await foursquareService.fetchRecommendations({
          latitude,
          longitude,
          preference,
          limit,
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

function parsePreferenceList(value) {
  if (Array.isArray(value)) {
    return value.flatMap(parsePreferenceList);
  }
  return String(value ?? "")
    .split(",")
    .map((preference) => preference.trim())
    .filter((preference) => preference.length > 0);
}

function parseRecommendationLimit(value) {
  const parsed = Number(value);
  return [3, 5, 10].includes(parsed) ? parsed : 5;
}

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

