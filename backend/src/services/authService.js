/**
 * Authentication service.
 *
 * This file centralizes security helpers for hashing passwords, comparing login
 * passwords, generating JWT tokens, and verifying JWT tokens.
 */
const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");
const crypto = require("crypto");

const JWT_SECRET = process.env.JWT_SECRET || "your_jwt_super_secret_key_here";
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || "7d";
const EMAIL_VERIFICATION_EXPIRES_IN_MS = Number(
  process.env.EMAIL_VERIFICATION_EXPIRES_IN_MS || 24 * 60 * 60 * 1000,
);
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
  const token = crypto.randomBytes(32).toString("hex");
  return {
    token,
    tokenHash: hashToken(token),
    expiresAt: new Date(Date.now() + EMAIL_VERIFICATION_EXPIRES_IN_MS)
      .toISOString(),
  };
}

function hashToken(token) {
  return crypto.createHash("sha256").update(String(token)).digest("hex");
}

module.exports = {
  comparePassword,
  createEmailVerificationToken,
  generateToken,
  hashPassword,
  hashToken,
  verifyToken,
};
