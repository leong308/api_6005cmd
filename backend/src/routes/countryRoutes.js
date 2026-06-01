const express = require("express");
const { getCountryInfo } = require("../controllers/countryController");

const countryRouter = express.Router();

countryRouter.get("/:name", getCountryInfo);

module.exports = {
  countryRouter,
};
