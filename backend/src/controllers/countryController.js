/**
 * Country controller.
 *
 * This file handles HTTP request/response work for country lookups. The actual
 * provider call is kept in `countryService`, so this controller only reads route
 * parameters, calls the service, and returns JSON.
 */
const countryService = require("../services/countryService");

/**
 * Controller handler for fetching country details.
 */
async function getCountryInfo(req, res, next) {
  try {
    const countryName = req.params.name;
    const countryData = await countryService.fetchCountryData(countryName);
    
    return res.status(200).json({
      success: true,
      data: countryData,
    });
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  getCountryInfo,
};
