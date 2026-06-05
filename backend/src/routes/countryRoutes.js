/**
 * Country routes.
 *
 * This file maps `/api/countries/:name` to the country controller so the app can
 * fetch capital, currency, language, region, country code, and flag data.
 */
const express = require("express");
const { getCountryInfo } = require("../controllers/countryController");

const countryRouter = express.Router();

countryRouter.get("/:name", getCountryInfo);

module.exports = {
  countryRouter,
};
