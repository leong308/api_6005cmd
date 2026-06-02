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

    const summaryData = await summaryService.generateSummary(
      tripId,
      host,
      scheme,
      { recommendationLimit, recommendationLimits },
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
      const limit = parseRecommendationLimit(rawLimit);
      if (preference.length === 0) {
        return limits;
      }
      return { ...limits, [preference]: limit };
    }, {});
}

module.exports = {
  getTripSummary,
};
