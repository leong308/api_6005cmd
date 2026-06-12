/**
 * Backend startup entry point.
 *
 * This file creates the Express app, attaches final not-found/error middleware,
 * and starts listening on the configured port. This is the file run by
 * `npm start` or `npm run dev`.
 */
const { createApp } = require("./app");
const { env } = require("./config/env");
const { globalErrorHandler } = require("./middleware/errorHandler");
const { notFoundHandler } = require("./middleware/error-handler");
const {
  startExpiredUnverifiedUserCleanup,
} = require("./services/unverifiedUserCleanupService");

const app = createApp();

// Fallback for page/route not found
app.use(notFoundHandler);

// Global error handler placed at the bottom, after all routes/middlewares
app.use(globalErrorHandler);

/**
 * Starts the HTTP server on the configured port.
 */
app.listen(process.env.PORT || env.port, () => {
  console.log(`Smart Travel Planner API running`);
});

startExpiredUnverifiedUserCleanup();

