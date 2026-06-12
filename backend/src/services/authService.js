/**
 * Authentication service.
 *
 * This file centralizes security helpers for hashing passwords, comparing login
 * passwords, generating JWT tokens, and verifying JWT tokens.
 */
const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");
const crypto = require("crypto");
require("../config/env");

const PLACEHOLDER_JWT_SECRETS = new Set([
  "5aea10d806a87e648846bd561f2a54c3d09a60502c9de02cbabd1a282201d0af72cc7eca38b11de3059ce4658921177249a41f4bd5d354461f4cdfc4af8f627c",
  "676c4c23c24607a2bde15a201d7512cf517a8c89a1a946a532d430037d4c77c35852466ce44768bdb1a848a55e02fc105d2978207eeaec53161cd710bac5dfbb",
  "replace_with_a_long_random_secret",
  "your_jwt_super_secret_key_here",
]);
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || "7d";
const JWT_ALGORITHM = "HS256";
const JWT_ISSUER = readOptionalString(process.env.JWT_ISSUER);
const JWT_AUDIENCE = readOptionalString(process.env.JWT_AUDIENCE);
const DEFAULT_EMAIL_VERIFICATION_EXPIRES_IN_MS = 2 * 60 * 60 * 1000;
const EMAIL_VERIFICATION_EXPIRES_IN_MS = readEmailVerificationExpiryMs();
const DEFAULT_PASSWORD_RESET_EXPIRES_IN_MS = 2 * 60 * 60 * 1000;
const PASSWORD_RESET_EXPIRES_IN_MS = readPasswordResetExpiryMs();
const SALT_ROUNDS = 10;
const MIN_JWT_SECRET_LENGTH = 32;

let developmentJwtSecret = null;

/**
 * Hash a plain-text password using bcrypt.
 * @param {string} plainPassword
 * @returns {Promise<string>} The hashed password.
 */
async function hashPassword(plainPassword) {
  return bcrypt.hash(plainPassword, SALT_ROUNDS);
}

/**
 * Compare a plain-text password against a bcrypt hash.
 * @param {string} plainPassword
 * @param {string} hashedPassword
 * @returns {Promise<boolean>}
 */
async function comparePassword(plainPassword, hashedPassword) {
  return bcrypt.compare(plainPassword, hashedPassword);
}

/**
 * Generate a signed JWT token for a given user payload.
 * @param {{ id: string, email: string }} user
 * @returns {string} Signed JWT token.
 */
function generateToken(user) {
  return jwt.sign({ id: user.id, email: user.email }, readJwtSecret(), {
    algorithm: JWT_ALGORITHM,
    subject: String(user.id),
    expiresIn: JWT_EXPIRES_IN,
    ...optionalJwtClaims(),
  });
}

/**
 * Verify and decode a JWT token.
 * @param {string} token
 * @returns {{ id: string, email: string }} Decoded payload.
 * @throws {Error} If the token is invalid or expired.
 */
function verifyToken(token) {
  return jwt.verify(token, readJwtSecret(), {
    algorithms: [JWT_ALGORITHM],
    ...optionalJwtClaims(),
  });
}

/**
 * Creates the email verification token data.
 */
function createEmailVerificationToken() {
  return createExpiringToken(EMAIL_VERIFICATION_EXPIRES_IN_MS);
}

/**
 * Creates the password reset token data.
 */
function createPasswordResetToken() {
  return createExpiringToken(PASSWORD_RESET_EXPIRES_IN_MS);
}

/**
 * Creates the expiring token data.
 */
function createExpiringToken(expiresInMs) {
  const token = crypto.randomBytes(32).toString("hex");
  return {
    token,
    tokenHash: hashToken(token),
    expiresAt: new Date(Date.now() + expiresInMs).toISOString(),
  };
}

/**
 * Hashes the token value.
 */
function hashToken(token) {
  return crypto.createHash("sha256").update(String(token)).digest("hex");
}

/**
 * Reads the email verification expiry ms value from configuration or input.
 */
function readEmailVerificationExpiryMs() {
  const configured = Number(process.env.EMAIL_VERIFICATION_EXPIRES_IN_MS);
  return Number.isFinite(configured) && configured > 0
    ? configured
    : DEFAULT_EMAIL_VERIFICATION_EXPIRES_IN_MS;
}

/**
 * Reads the password reset expiry ms value from configuration or input.
 */
function readPasswordResetExpiryMs() {
  const configured = Number(process.env.PASSWORD_RESET_EXPIRES_IN_MS);
  return Number.isFinite(configured) && configured > 0
    ? configured
    : DEFAULT_PASSWORD_RESET_EXPIRES_IN_MS;
}

/**
 * Reads the jwt secret value from configuration or input.
 */
function readJwtSecret() {
  const configured = String(process.env.JWT_SECRET ?? "").trim();
  const validationError = validateJwtSecret(configured);
  if (!validationError) {
    return configured;
  }

  if (!isProduction()) {
    if (!developmentJwtSecret) {
      developmentJwtSecret = crypto.randomBytes(64).toString("hex");
      console.warn(
        `JWT_SECRET ${validationError}. Using an ephemeral development JWT secret. ` +
          "Set JWT_SECRET in backend/.env to keep tokens valid after restart.",
      );
    }
    return developmentJwtSecret;
  }

  throw new JwtConfigurationError(
    `JWT_SECRET ${validationError}. Set a long random JWT_SECRET before using authentication.`,
  );
}

/**
 * Validates the jwt secret input.
 */
function validateJwtSecret(value) {
  if (!value) {
    return "is not configured";
  }
  if (PLACEHOLDER_JWT_SECRETS.has(value)) {
    return "is still set to a placeholder value";
  }
  if (value.length < MIN_JWT_SECRET_LENGTH) {
    return `must be at least ${MIN_JWT_SECRET_LENGTH} characters long`;
  }
  return "";
}

/**
 * Supports the optional jwt claims backend flow.
 */
function optionalJwtClaims() {
  return {
    ...(JWT_ISSUER ? { issuer: JWT_ISSUER } : {}),
    ...(JWT_AUDIENCE ? { audience: JWT_AUDIENCE } : {}),
  };
}

/**
 * Reads the optional string value from configuration or input.
 */
function readOptionalString(value) {
  const normalized = String(value ?? "").trim();
  return normalized.length > 0 ? normalized : null;
}

/**
 * Checks whether production is true.
 */
function isProduction() {
  return String(process.env.NODE_ENV ?? "").trim().toLowerCase() === "production";
}

class JwtConfigurationError extends Error {
  constructor(message) {
    super(message);
    this.name = "JwtConfigurationError";
    this.statusCode = 503;
  }
}

module.exports = {
  comparePassword,
  createEmailVerificationToken,
  createPasswordResetToken,
  EMAIL_VERIFICATION_EXPIRES_IN_MS,
  generateToken,
  hashPassword,
  hashToken,
  JwtConfigurationError,
  PASSWORD_RESET_EXPIRES_IN_MS,
  verifyToken,
};
