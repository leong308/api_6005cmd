const express = require("express");
const { getTripSummary } = require("../controllers/summaryController");

const summaryRouter = express.Router();

summaryRouter.get("/:id/summary", getTripSummary);

module.exports = {
  summaryRouter,
};
