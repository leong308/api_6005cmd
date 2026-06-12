/**
 * Health-check routes.
 *
 * This file exposes a lightweight endpoint used to confirm the backend process
 * is running and can return JSON.
 */
const express = require("express");

const healthRouter = express.Router();

/**
 * Handles GET / requests for the health API.
 */
healthRouter.get("/", (req, res) => {
  res.json({
    success: true,
    service: "smart-travel-planner-backend",
    timestamp: new Date().toISOString(),
  });
});

module.exports = { healthRouter };
