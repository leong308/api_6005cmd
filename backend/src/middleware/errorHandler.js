/**
 * Global centralized error-handling middleware.
 * Intercepts all errors, formats them cleanly, and conditionally prints stack traces in development mode.
 */
const globalErrorHandler = (err, req, res, next) => {
  const requestedStatusCode = Number(err.status || err.statusCode);
  const statusCode =
    Number.isInteger(requestedStatusCode) &&
    requestedStatusCode >= 400 &&
    requestedStatusCode <= 599
      ? requestedStatusCode
      : 500;
  const isDev = process.env.NODE_ENV !== "production";
  const message =
    statusCode >= 500 && !isDev
      ? "Internal Server Error"
      : err.message || "Internal Server Error";

  const response = {
    success: false,
    statusCode,
    message,
    ...(err.details !== undefined && (statusCode < 500 || isDev)
      ? { details: err.details }
      : {}),
  };

  if (isDev) {
    response.stack = err.stack;
    console.error(err);
  }

  return res.status(statusCode).json(response);
};

module.exports = { globalErrorHandler };
