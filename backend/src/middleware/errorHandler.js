/**
 * Global centralized error-handling middleware.
 * Intercepts all errors, formats them cleanly, and conditionally prints stack traces in development mode.
 */
const globalErrorHandler = (err, req, res, next) => {
  const statusCode = err.status || err.statusCode || 500;
  const isDev = process.env.NODE_ENV !== "production";

  const response = {
    success: false,
    statusCode,
    message: err.message || "Internal Server Error",
  };

  if (isDev) {
    response.stack = err.stack;
    console.error(err);
  }

  return res.status(statusCode).json(response);
};

module.exports = { globalErrorHandler };
