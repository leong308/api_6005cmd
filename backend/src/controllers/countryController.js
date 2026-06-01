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
