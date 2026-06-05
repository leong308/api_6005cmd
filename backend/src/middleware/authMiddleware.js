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
 * Throws 401 if the token is missing, malformed, or expired.
 */
function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    throw new HttpError(401, "Access denied. No token provided.");
  }

  const token = authHeader.split(" ")[1];

  try {
    const decoded = verifyToken(token);
    req.user = decoded; // { id, email }
    next();
  } catch (err) {
    if (err.name === "TokenExpiredError") {
      throw new HttpError(401, "Token has expired. Please log in again.");
    }
    throw new HttpError(401, "Invalid token.");
  }
}

module.exports = { authMiddleware };
