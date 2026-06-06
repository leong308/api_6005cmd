/**
 * Express app factory.
 *
 * This file creates the backend application instance, applies app-level
 * middleware, exposes a root status endpoint, and mounts the complete API
 * router under `/api`. The server listener stays in `server.js`, so this file
 * only describes how requests are handled once Express receives them.
 */
const express = require("express");
const cors = require("cors");
const { env } = require("./config/env");
const { apiRouter } = require("./routes");


function createApp() {
  const app = express();

  app.use(
    cors({
      origin: resolveCorsOrigin,
      credentials: true,
    }),
  );

  app.use(express.json({ limit: "1mb" }));
  app.use(express.urlencoded({ extended: false }));

  app.get("/", (req, res) => {
    res.json({
      success: true,
      message: "Smart Travel Planner API is running.",
      apiBase: "/api",
    });
  });

  app.use("/api", apiRouter);

  return app;
}

function resolveCorsOrigin(origin, callback) {
  if (!origin || env.corsOrigin === true) {
    return callback(null, true);
  }

  if (Array.isArray(env.corsOrigin) && env.corsOrigin.includes(origin)) {
    return callback(null, true);
  }

  if (isLocalDevelopmentOrigin(origin)) {
    return callback(null, true);
  }

  return callback(new Error(`CORS origin is not allowed: ${origin}`), false);
}

function isLocalDevelopmentOrigin(origin) {
  try {
    const url = new URL(origin);
    const hostname = url.hostname.toLowerCase();
    return (
      ["localhost", "127.0.0.1", "::1"].includes(hostname) &&
      ["http:", "https:"].includes(url.protocol)
    );
  } catch (_error) {
    return false;
  }
}

module.exports = { createApp };

