/**
 * Trip summary routes.
 *
 * This file defines the combined summary endpoint. Mounted under `/api/trips`,
 * it exposes `GET /api/trips/:id/summary`.
 */
const express = require("express");
const { getTripSummary } = require("../controllers/summaryController");

const summaryRouter = express.Router();

summaryRouter.get("/:id/summary", getTripSummary);

module.exports = {
  summaryRouter,
};
