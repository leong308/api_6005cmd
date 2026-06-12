/**
 * Trip summary routes.
 *
 * This file defines the combined summary endpoint. Mounted under `/api/trips`,
 * it exposes `GET /api/trips/:id/summary`.
 */
const express = require("express");
const { getTripSummary } = require("../controllers/summaryController");
const { authMiddleware } = require("../middleware/authMiddleware");

const summaryRouter = express.Router();

/**
 * Handles GET /:id/summary requests for the summary API.
 */
summaryRouter.get("/:id/summary", authMiddleware, getTripSummary);

module.exports = {
  summaryRouter,
};
