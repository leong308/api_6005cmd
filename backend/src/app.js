const express = require("express");
const cors = require("cors");
const { env } = require("./config/env");
const { apiRouter } = require("./routes");
const { notFoundHandler, errorHandler } = require("./middleware/error-handler");

function createApp() {
  const app = express();

  app.use(
    cors({
      origin: env.corsOrigin,
      credentials: true,
    }),
  );

  app.use(express.json({ limit: "1mb" }));

  app.get("/", (req, res) => {
    res.json({
      success: true,
      message: "Smart Travel Planner API is running.",
      apiBase: "/api",
    });
  });

  app.use("/api", apiRouter);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}

module.exports = { createApp };
