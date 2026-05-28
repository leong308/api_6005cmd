const express = require("express");
const { healthRouter } = require("./health.routes");
const { tripRouter } = require("./trips.routes");
const { authRouter } = require("./auth.routes");
const { externalRouter } = require("./external.routes");

const apiRouter = express.Router();

apiRouter.use("/health", healthRouter);
apiRouter.use("/trips", tripRouter);
apiRouter.use("/auth", authRouter);
apiRouter.use("/external", externalRouter);

module.exports = { apiRouter };
