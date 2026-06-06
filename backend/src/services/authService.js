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
]);
const JWT_SECRET = readJwtSecret();
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || "7d";
const DEFAULT_EMAIL_VERIFICATION_EXPIRES_IN_MS = 2 * 60 * 60 * 1000;
const EMAIL_VERIFICATION_EXPIRES_IN_MS = readEmailVerificationExpiryMs();
const DEFAULT_PASSWORD_RESET_EXPIRES_IN_MS = 2 * 60 * 60 * 1000;
const PASSWORD_RESET_EXPIRES_IN_MS = readPasswordResetExpiryMs();
const SALT_ROUNDS = 10;

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
  return jwt.sign({ id: user.id, email: user.email }, JWT_SECRET, {
    expiresIn: JWT_EXPIRES_IN,
  });
}

/**
 * Verify and decode a JWT token.
 * @param {string} token
 * @returns {{ id: string, email: string }} Decoded payload.
 * @throws {Error} If the token is invalid or expired.
 */
function verifyToken(token) {
  return jwt.verify(token, JWT_SECRET);
}

function createEmailVerificationToken() {
  return createExpiringToken(EMAIL_VERIFICATION_EXPIRES_IN_MS);
}

function createPasswordResetToken() {
  return createExpiringToken(PASSWORD_RESET_EXPIRES_IN_MS);
}

function createExpiringToken(expiresInMs) {
  const token = crypto.randomBytes(32).toString("hex");
  return {
    token,
    tokenHash: hashToken(token),
    expiresAt: new Date(Date.now() + expiresInMs).toISOString(),
  };
}

function hashToken(token) {
  return crypto.createHash("sha256").update(String(token)).digest("hex");
}

function readEmailVerificationExpiryMs() {
  const configured = Number(process.env.EMAIL_VERIFICATION_EXPIRES_IN_MS);
  return Number.isFinite(configured) && configured > 0
    ? configured
    : DEFAULT_EMAIL_VERIFICATION_EXPIRES_IN_MS;
}

function readPasswordResetExpiryMs() {
  const configured = Number(process.env.PASSWORD_RESET_EXPIRES_IN_MS);
  return Number.isFinite(configured) && configured > 0
    ? configured
    : DEFAULT_PASSWORD_RESET_EXPIRES_IN_MS;
}

function readJwtSecret() {
  const configured = String(process.env.JWT_SECRET ?? "").trim();
  if (configured && !PLACEHOLDER_JWT_SECRETS.has(configured)) {
    return configured;
  }
  throw new Error("A non-placeholder JWT_SECRET is required in backend/.env.");
}

module.exports = {
  comparePassword,
  createEmailVerificationToken,
  createPasswordResetToken,
  EMAIL_VERIFICATION_EXPIRES_IN_MS,
  generateToken,
  hashPassword,
  hashToken,
  PASSWORD_RESET_EXPIRES_IN_MS,
  verifyToken,
};
