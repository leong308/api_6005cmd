/**
 * Trip summary controller.
 *
 * This file handles requests for the combined trip summary endpoint. It reads
 * the trip ID and query parameters, passes them to `summaryService`, and returns
 * one aggregated JSON response to the Flutter app.
 */
const summaryService = require("../services/summaryService");

/**
 * Controller handler for generating unified trip summary.
 */
async function getTripSummary(req, res, next) {
  try {
    const tripId = req.params.id;
    const host = req.headers.host || "localhost:3000";
    const scheme = req.secure ? "https" : "http";
    const recommendationLimit = parseRecommendationLimit(
      req.query.recommendationLimit,
    );
    const recommendationLimits = parseRecommendationLimits(
      req.query.recommendationLimits,
    );
    const routeMapDays = parseRouteMapDays(req.query.routeMapDays);
    const routeMapDayIndexes = parseRouteMapDayIndexes(
      req.query.routeMapDayIndexes,
    );
    const availabilityDays = parseAvailabilityDays(req.query.availabilityDays);
    const forceRefresh = parseBooleanQuery(
      req.query.refresh ?? req.query.forceRefresh,
    );

    const summaryData = await summaryService.generateSummary(
      tripId,
      host,
      scheme,
      {
        recommendationLimit,
        recommendationLimits,
        routeMapDays,
        routeMapDayIndexes,
        availabilityDays,
        forceRefresh,
        userId: req.user.id,
      },
    );

    return res.status(200).json({
      success: true,
      tripId,
      data: summaryData,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Parses the recommendation limit value into the backend format.
 */
function parseRecommendationLimit(value) {
  const parsed = Number(value);
  return [3, 5, 10].includes(parsed) ? parsed : 5;
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
      const limit = parseRecommendationLimit(rawLimit);
      if (preference.length === 0) {
        return limits;
      }
      return { ...limits, [preference]: limit };
    }, {});
}

/**
 * Parses the route map days value into the backend format.
 */
function parseRouteMapDays(value) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed)) {
    return 0;
  }
  return Math.min(Math.max(parsed, 0), 21);
}

/**
 * Parses the route map day indexes value into the backend format.
 */
function parseRouteMapDayIndexes(value) {
  if (Array.isArray(value)) {
    return value.flatMap(parseRouteMapDayIndexes);
  }

  return String(value ?? "")
    .split(",")
    .map((item) => Number(item.trim()))
    .filter((item) => Number.isInteger(item) && item >= 0 && item < 21);
}

/**
 * Parses the availability days value into the backend format.
 */
function parseAvailabilityDays(value) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed)) {
    return 1;
  }
  return Math.min(Math.max(parsed, 0), 7);
}

/**
 * Parses the boolean query value into the backend format.
 */
function parseBooleanQuery(value) {
  return ["1", "true", "yes", "force"].includes(
    String(value ?? "").trim().toLowerCase(),
  );
}

module.exports = {
  getTripSummary,
};
