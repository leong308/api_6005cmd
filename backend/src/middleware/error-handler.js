/**
 * Generic fallback/error middleware.
 *
 * This file provides a 404 handler for unmatched routes and a simple
 * `HttpError`-aware error handler. `server.js` uses the not-found handler after
 * all routes are mounted.
 */
const { HttpError } = require("../lib/http");

/**
 * Supports the not found handler backend flow.
 */
function notFoundHandler(req, res) {
  res.status(404).json({
    success: false,
    message: `Route not found: ${req.method} ${req.originalUrl}`,
  });
}

/**
 * Supports the error handler backend flow.
 */
function errorHandler(err, req, res, _next) {
  if (err instanceof HttpError) {
    return res.status(err.statusCode).json({
      success: false,
      message: err.message,
      details: err.details,
    });
  }

  console.error(err);
  return res.status(500).json({
    success: false,
    message: "Internal server error.",
  });
}

module.exports = {
  notFoundHandler,
  errorHandler,
};
