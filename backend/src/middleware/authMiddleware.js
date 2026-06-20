/**
 * JWT authentication middleware.
 *
 * This file protects routes that require a logged-in user. It verifies the
 * `Authorization: Bearer <token>` header and attaches the decoded user payload
 * to `req.user` for downstream route handlers.
 */
const { verifyToken } = require("../services/authService");
const { HttpError } = require("../lib/http");

/**
 * Express middleware that verifies a JWT Bearer token.
 * Attaches the decoded user payload to `req.user` if valid.
 * Calls next(err) with a 401 HttpError if the token is missing, malformed, or expired.
 */
function authMiddleware(req, res, next) {
  const authHeader = String(req.headers.authorization ?? "");
  const match = authHeader.match(/^Bearer\s+(\S+)$/i);

  if (!match) {
    return next(new HttpError(401, "Access denied. No token provided."));
  }

  const token = match[1];

  try {
    const decoded = verifyToken(token);
    req.user = decoded; // { id, email }
    next();
  } catch (err) {
    if (err.statusCode) {
      return next(err);
    }
    if (err.name === "TokenExpiredError") {
      return next(new HttpError(401, "Token has expired. Please log in again."));
    }
    return next(new HttpError(401, "Invalid token."));
  }
}

module.exports = { authMiddleware };
