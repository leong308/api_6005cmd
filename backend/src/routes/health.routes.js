const express = require("express");

const healthRouter = express.Router();

healthRouter.get("/", (req, res) => {
  res.json({
    success: true,
    service: "smart-travel-planner-backend",
    timestamp: new Date().toISOString(),
  });
});

module.exports = { healthRouter };
