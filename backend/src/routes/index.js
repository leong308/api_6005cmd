/**
 * Main API router registry.
 *
 * This file groups every feature router under the `/api` prefix mounted in
 * `app.js`. It is the backend routing table for trips, summary aggregation,
 * authentication, external proxy APIs, countries, and health checks.
 */
const express = require("express");
const { healthRouter } = require("./health.routes");
const { tripRouter } = require("./trips.routes");
const { authRouter } = require("./auth.routes");
const { externalRouter } = require("./external.routes");
const { countryRouter } = require("./countryRoutes");
const { summaryRouter } = require("./summaryRoutes");

const apiRouter = express.Router();

apiRouter.use("/health", healthRouter);
apiRouter.use("/trips", summaryRouter);
apiRouter.use("/trips", tripRouter);
apiRouter.use("/auth", authRouter);
apiRouter.use("/external", externalRouter);
apiRouter.use("/countries", countryRouter);

module.exports = { apiRouter };
