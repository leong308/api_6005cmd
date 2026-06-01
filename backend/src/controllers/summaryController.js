const summaryService = require("../services/summaryService");

/**
 * Controller handler for generating unified trip summary.
 */
async function getTripSummary(req, res, next) {
  try {
    const tripId = req.params.id;
    const host = req.headers.host || "localhost:3000";
    const scheme = req.secure ? "https" : "http";

    const summaryData = await summaryService.generateSummary(tripId, host, scheme);

    return res.status(200).json({
      success: true,
      tripId,
      data: summaryData,
    });
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  getTripSummary,
};
