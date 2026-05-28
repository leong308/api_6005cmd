const express = require("express");
const { HttpError } = require("../lib/http");

const externalRouter = express.Router();

function ensureCoordinates(req) {
  const latitude = Number(req.query.lat);
  const longitude = Number(req.query.lng);

  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    throw new HttpError(400, "Query params lat and lng are required numbers.");
  }

  return { latitude, longitude };
}

externalRouter.get("/weather", (req, res) => {
  const { latitude, longitude } = ensureCoordinates(req);

  res.json({
    success: true,
    provider: "mock-openweather-proxy",
    data: {
      latitude,
      longitude,
      temperature: 28,
      condition: "Cloudy",
      humidity: 72,
      windSpeed: 2.9,
    },
  });
});

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

externalRouter.get("/recommendations", (req, res) => {
  const { latitude, longitude } = ensureCoordinates(req);
  const preference = String(req.query.preference ?? "family");

  res.json({
    success: true,
    provider: "mock-foursquare-proxy",
    data: [
      {
        name: `${preference} recommendation #1`,
        category: preference,
        distanceMeters: 1200,
        coordinates: { latitude, longitude },
      },
      {
        name: `${preference} recommendation #2`,
        category: preference,
        distanceMeters: 2800,
        coordinates: { latitude, longitude },
      },
    ],
  });
});

externalRouter.get("/country-info", (req, res) => {
  const country = String(req.query.country ?? "").trim();
  if (!country) {
    throw new HttpError(400, "Query param country is required.");
  }

  res.json({
    success: true,
    provider: "mock-rest-countries-proxy",
    data: {
      country,
      capital: "Not configured",
      currency: "Not configured",
      languages: [],
      region: "Not configured",
    },
  });
});

module.exports = { externalRouter };
