const express = require("express");
const {
  listTrips,
  getTripById,
  createTrip,
  updateTrip,
  deleteTrip,
  getTripGooglePlaces,
} = require("../data/store");
const { HttpError, assertRequiredFields } = require("../lib/http");
const agendaService = require("../services/agendaService");
const countryService = require("../services/countryService");
const foursquareService = require("../services/foursquareService");
const weatherService = require("../services/weatherService");

const tripRouter = express.Router();


tripRouter.get("/", (req, res) => {
  const trips = listTrips();
  res.json({
    success: true,
    total: trips.length,
    data: trips,
  });
});

tripRouter.post("/", (req, res) => {
  assertRequiredFields(req.body, [
    "destinationName",
    "destinationCountry",
    "latitude",
    "longitude",
    "startDate",
    "endDate",
  ]);

  const created = createTrip(req.body);
  res.status(201).json({
    success: true,
    message: "Trip created.",
    data: created,
  });
});

tripRouter.get("/:id/weather", async (req, res, next) => {
  try {
    const trip = getTripById(req.params.id);
    if (!trip) {
      throw new HttpError(404, "Trip not found.");
    }

    const data = await weatherService.fetchCurrentWeather(
      trip.latitude,
      trip.longitude,
    );

    return res.json({
      success: true,
      provider: "open-meteo",
      tripId: req.params.id,
      data,
    });
  } catch (error) {
    return next(error);
  }
});

tripRouter.get("/:id/weather/forecast", async (req, res, next) => {
  try {
    const trip = getTripById(req.params.id);
    if (!trip) {
      throw new HttpError(404, "Trip not found.");
    }

    const data = await weatherService.fetchDailyForecast(
      trip.latitude,
      trip.longitude,
      trip.startDate,
      trip.endDate,
    );

    return res.json({
      success: true,
      provider: "open-meteo",
      tripId: req.params.id,
      data,
    });
  } catch (error) {
    return next(error);
  }
});

tripRouter.get("/:id/google-places", (req, res) => {
  const trip = getTripById(req.params.id);
  if (!trip) {
    throw new HttpError(404, "Trip not found.");
  }

  res.json({
    success: true,
    tripId: req.params.id,
    data: getTripGooglePlaces(req.params.id),
  });
});

tripRouter.get("/:id/recommendations", async (req, res, next) => {
  try {
    const trip = getTripById(req.params.id);
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
      provider: "foursquare",
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
    const trip = getTripById(req.params.id);
    if (!trip) {
      throw new HttpError(404, "Trip not found.");
    }

    const limit = parseRecommendationLimit(req.query.limit);
    const limitsByPreference = parseRecommendationLimits(
      req.query.recommendationLimits ?? req.query.limits,
    );
    const availabilityDays = parseAvailabilityDays(req.query.availabilityDays);
    const routeMapDays = parseRouteMapDays(req.query.routeMapDays);
    const [dailyWeatherForecast, recommendationGroups] = await Promise.all([
      weatherService
        .fetchDailyForecast(
          trip.latitude,
          trip.longitude,
          trip.startDate,
          trip.endDate,
        )
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
    });

    return res.json({
      success: true,
      provider: "smart-travel-planner",
      tripId: req.params.id,
      data,
    });
  } catch (error) {
    return next(error);
  }
});

tripRouter.get("/:id/country-info", async (req, res, next) => {
  try {
    const trip = getTripById(req.params.id);
    if (!trip) {
      throw new HttpError(404, "Trip not found.");
    }

    const countryData = await countryService.fetchCountryData(trip.destinationCountry);

    return res.json({
      success: true,
      tripId: req.params.id,
      data: countryData,
    });
  } catch (error) {
    return next(error);
  }
});

tripRouter.get("/:id", (req, res) => {
  const trip = getTripById(req.params.id);
  if (!trip) {
    throw new HttpError(404, "Trip not found.");
  }

  res.json({
    success: true,
    data: trip,
  });
});

tripRouter.put("/:id", (req, res) => {
  const updated = updateTrip(req.params.id, req.body);
  if (!updated) {
    throw new HttpError(404, "Trip not found.");
  }

  res.json({
    success: true,
    message: "Trip updated.",
    data: updated,
  });
});

tripRouter.delete("/:id", (req, res) => {
  const deleted = deleteTrip(req.params.id);
  if (!deleted) {
    throw new HttpError(404, "Trip not found.");
  }

  res.json({
    success: true,
    message: "Trip deleted.",
  });
});

module.exports = { tripRouter };

function parseRecommendationLimit(value) {
  const parsed = Number(value);
  return [3, 5, 10].includes(parsed) ? parsed : 5;
}

function parseRouteMapDays(value) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed)) {
    return 1;
  }
  return Math.min(Math.max(parsed, 0), 7);
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
