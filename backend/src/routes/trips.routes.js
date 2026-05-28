const express = require("express");
const {
  listTrips,
  getTripById,
  createTrip,
  updateTrip,
  deleteTrip,
  getTripWeather,
  getTripGooglePlaces,
  getTripRecommendations,
  getTripCountryInfo,
  getTripSummary,
} = require("../data/store");
const { HttpError, assertRequiredFields } = require("../lib/http");

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

tripRouter.get("/:id/weather", (req, res) => {
  const trip = getTripById(req.params.id);
  if (!trip) {
    throw new HttpError(404, "Trip not found.");
  }

  res.json({
    success: true,
    tripId: req.params.id,
    data: getTripWeather(req.params.id),
  });
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

tripRouter.get("/:id/recommendations", (req, res) => {
  const trip = getTripById(req.params.id);
  if (!trip) {
    throw new HttpError(404, "Trip not found.");
  }

  res.json({
    success: true,
    tripId: req.params.id,
    data: getTripRecommendations(req.params.id),
  });
});

tripRouter.get("/:id/country-info", (req, res) => {
  const trip = getTripById(req.params.id);
  if (!trip) {
    throw new HttpError(404, "Trip not found.");
  }

  res.json({
    success: true,
    tripId: req.params.id,
    data: getTripCountryInfo(req.params.id),
  });
});

tripRouter.get("/:id/summary", (req, res) => {
  const summary = getTripSummary(req.params.id);
  if (!summary) {
    throw new HttpError(404, "Trip not found.");
  }

  res.json({
    success: true,
    tripId: req.params.id,
    data: summary,
  });
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
