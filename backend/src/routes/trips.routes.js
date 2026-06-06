/**
 * Trip routes.
 *
 * This file contains the self-developed trip API: list, create, read, update,
 * delete, and trip-specific module endpoints such as weather, forecast,
 * recommendations, agenda, and country information.
 */
const express = require("express");
const {
  listTrips,
  getTripById,
  createTrip,
  updateTrip,
  deleteTrip,
  getTripGooglePlaces,
} = require("../data/repository");
const cacheRepository = require("../data/cacheRepository");
const { authMiddleware } = require("../middleware/authMiddleware");
const {
  HttpError,
  assertProvidedFieldsNotEmpty,
  assertRequiredFields,
} = require("../lib/http");
const agendaService = require("../services/agendaService");
const countryService = require("../services/countryService");
const foursquareService = require("../services/foursquareService");
const reverseGeocodeService = require("../services/reverseGeocodeService");
const tripWeatherFileCache = require("../services/tripWeatherFileCache");
const tripWeatherService = require("../services/tripWeatherService");

const tripRouter = express.Router();
const REQUIRED_TRIP_FIELDS = [
  "destinationName",
  "destinationCountry",
  "latitude",
  "longitude",
  "startDate",
  "endDate",
];

tripRouter.use(authMiddleware);

tripRouter.get("/", async (req, res, next) => {
  try {
    const trips = await listTrips(req.user.id);
    res.json({
      success: true,
      total: trips.length,
      data: trips,
    });
  } catch (error) {
    next(error);
  }
});

tripRouter.post("/", async (req, res, next) => {
  try {
    assertRequiredFields(req.body, REQUIRED_TRIP_FIELDS);

    const created = await createTrip(req.body, req.user.id);
    res.status(201).json({
      success: true,
      message: "Trip created.",
      data: created,
    });
  } catch (error) {
    next(error);
  }
});

tripRouter.get("/:id/weather", async (req, res, next) => {
  try {
    const trip = await getTripById(req.params.id, req.user.id);
    if (!trip) {
      throw new HttpError(404, "Trip not found.");
    }

    const result = await tripWeatherService.fetchCurrentWeatherForTrip(trip);

    return res.json({
      success: true,
      provider: "open-meteo",
      tripId: req.params.id,
      cached: result.cached,
      stale: result.stale,
      ...(result.warning ? { warning: result.warning } : {}),
      data: result.data,
    });
  } catch (error) {
    return next(error);
  }
});

tripRouter.get("/:id/weather/forecast", async (req, res, next) => {
  try {
    const trip = await getTripById(req.params.id, req.user.id);
    if (!trip) {
      throw new HttpError(404, "Trip not found.");
    }

    const result = await tripWeatherService.fetchDailyForecastForTrip(trip);

    return res.json({
      success: true,
      provider: "open-meteo",
      tripId: req.params.id,
      cached: result.cached,
      stale: result.stale,
      ...(result.warning ? { warning: result.warning } : {}),
      data: result.data,
    });
  } catch (error) {
    return next(error);
  }
});

tripRouter.get("/:id/google-places", async (req, res, next) => {
  try {
    const trip = await getTripById(req.params.id, req.user.id);
    if (!trip) {
      throw new HttpError(404, "Trip not found.");
    }

    res.json({
      success: true,
      tripId: req.params.id,
      data: await getTripGooglePlaces(req.params.id),
    });
  } catch (error) {
    next(error);
  }
});

tripRouter.get("/:id/recommendations", async (req, res, next) => {
  try {
    const trip = await getTripById(req.params.id, req.user.id);
    if (!trip) {
      throw new HttpError(404, "Trip not found.");
    }

    const limit = parseRecommendationLimit(req.query.limit);
    const limitsByPreference = parseRecommendationLimits(
      req.query.recommendationLimits ?? req.query.limits,
    );
    const data = await foursquareService.fetchRecommendationGroups({
      latitude: trip.latitude,
      longitude: trip.longitude,
      preferences: trip.preferences,
      limit,
      limitsByPreference,
    });

    return res.json({
      success: true,
      provider: "foursquare-with-geoapify-fallback",
      tripId: req.params.id,
      limit,
      limits: Object.fromEntries(
        data.map((group) => [group.preference, group.limit]),
      ),
      data,
    });
  } catch (error) {
    return next(error);
  }
});

tripRouter.get("/:id/agenda", async (req, res, next) => {
  try {
    const trip = await getTripById(req.params.id, req.user.id);
    if (!trip) {
      throw new HttpError(404, "Trip not found.");
    }

    const limit = parseRecommendationLimit(req.query.limit);
    const limitsByPreference = parseRecommendationLimits(
      req.query.recommendationLimits ?? req.query.limits,
    );
    const availabilityDays = parseAvailabilityDays(req.query.availabilityDays);
    const routeMapDays = parseRouteMapDays(req.query.routeMapDays);
    const routeMapDayIndexes = parseRouteMapDayIndexes(
      req.query.routeMapDayIndexes,
    );
    const cacheKey = buildTripCacheKey(trip, "agenda", {
      availabilityDays,
      limit,
      limitsByPreference,
      routeMapDayIndexes,
      routeMapDays,
    });
    const cached = await cacheRepository.getCachedValue("trip_agenda", cacheKey);
    if (cached !== undefined) {
      return res.json({
        success: true,
        provider: "smart-travel-planner",
        tripId: req.params.id,
        cached: true,
        data: cached,
      });
    }

    const [dailyWeatherForecast, recommendationGroups] = await Promise.all([
      tripWeatherService
        .fetchDailyForecastForTrip(trip)
        .then((result) => result.data)
        .catch(() => null),
      foursquareService
        .fetchRecommendationGroups({
          latitude: trip.latitude,
          longitude: trip.longitude,
          preferences: trip.preferences,
          limit,
          limitsByPreference,
        })
        .catch(() => []),
    ]);

    const data = await agendaService.buildTimedTripAgenda({
      trip,
      dailyWeatherForecast,
      recommendationGroups,
      availabilityDays,
      routeMapDays,
      routeMapDayIndexes,
    });
    await cacheRepository.setCachedValue("trip_agenda", cacheKey, data, {
      metadata: { tripId: trip.id, provider: "smart-travel-planner" },
    });

    return res.json({
      success: true,
      provider: "smart-travel-planner",
      tripId: req.params.id,
      cached: false,
      data,
    });
  } catch (error) {
    return next(error);
  }
});

tripRouter.get("/:id/country-info", async (req, res, next) => {
  try {
    const trip = await getTripById(req.params.id, req.user.id);
    if (!trip) {
      throw new HttpError(404, "Trip not found.");
    }

    const countryName = await resolveTripCountryName(trip);
    const cacheKey = buildTripCacheKey(trip, "country", { countryName });
    const cached = await cacheRepository.getCachedValue("trip_country", cacheKey);
    if (cached !== undefined) {
      return res.json({
        success: true,
        tripId: req.params.id,
        cached: true,
        data: cached,
      });
    }

    const countryData = await countryService.fetchCountryData(countryName);
    await cacheRepository.setCachedValue("trip_country", cacheKey, countryData, {
      metadata: { tripId: trip.id, provider: "rest-countries" },
    });

    return res.json({
      success: true,
      tripId: req.params.id,
      cached: false,
      data: countryData,
    });
  } catch (error) {
    return next(error);
  }
});

tripRouter.get("/:id", async (req, res, next) => {
  try {
    const trip = await getTripById(req.params.id, req.user.id);
    if (!trip) {
      throw new HttpError(404, "Trip not found.");
    }

    res.json({
      success: true,
      data: trip,
    });
  } catch (error) {
    next(error);
  }
});

tripRouter.put("/:id", async (req, res, next) => {
  try {
    assertProvidedFieldsNotEmpty(req.body, REQUIRED_TRIP_FIELDS);
    const updated = await updateTrip(req.params.id, req.body, req.user.id);
    if (!updated) {
      throw new HttpError(404, "Trip not found.");
    }

    res.json({
      success: true,
      message: "Trip updated.",
      data: updated,
    });
  } catch (error) {
    next(error);
  }
});

tripRouter.delete("/:id", async (req, res, next) => {
  try {
    const deleted = await deleteTrip(req.params.id, req.user.id);
    if (!deleted) {
      throw new HttpError(404, "Trip not found.");
    }
    await tripWeatherFileCache.deleteTripWeatherCache(req.params.id);

    res.json({
      success: true,
      message: "Trip deleted.",
    });
  } catch (error) {
    next(error);
  }
});

module.exports = { tripRouter };

async function resolveTripCountryName(trip) {
  const storedCountry = String(trip.destinationCountry ?? "").trim();
  if (storedCountry.length > 0) {
    return storedCountry;
  }

  const result = await reverseGeocodeService.reverseGeocode(
    Number(trip.latitude),
    Number(trip.longitude),
  );
  const geocodedCountry = String(result.country ?? "").trim();
  if (geocodedCountry.length > 0) {
    return geocodedCountry;
  }

  throw new HttpError(404, "Country unavailable for this trip.");
}

function parseRecommendationLimit(value) {
  const parsed = Number(value);
  return [3, 5, 10].includes(parsed) ? parsed : 5;
}

function parseRouteMapDays(value) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed)) {
    return 0;
  }
  return Math.min(Math.max(parsed, 0), 21);
}

function parseRouteMapDayIndexes(value) {
  if (Array.isArray(value)) {
    return value.flatMap(parseRouteMapDayIndexes);
  }

  return String(value ?? "")
    .split(",")
    .map((item) => Number(item.trim()))
    .filter((item) => Number.isInteger(item) && item >= 0 && item < 21);
}

function parseAvailabilityDays(value) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed)) {
    return 1;
  }
  return Math.min(Math.max(parsed, 0), 7);
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

function buildTripCacheKey(trip, namespace, options = {}) {
  return [
    trip.id,
    trip.updatedAt ?? "",
    namespace,
    stableStringify(options),
  ].join(":");
}

function stableStringify(value) {
  if (Array.isArray(value)) {
    return `[${value.map(stableStringify).join(",")}]`;
  }
  if (value && typeof value === "object") {
    return `{${Object.keys(value)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${stableStringify(value[key])}`)
      .join(",")}}`;
  }
  return JSON.stringify(value);
}
