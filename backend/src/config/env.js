/**
 * Environment configuration loader.
 *
 * This file reads optional values from `backend/.env`, keeps existing deployed
 * environment variables untouched, and exposes normalized backend settings such
 * as the HTTP port and allowed CORS origins.
 */
const fs = require("fs");
const path = require("path");

const DEFAULT_PORT = 3000;

/**
 * Supports the load dot env backend flow.
 */
function loadDotEnv() {
  const envFile = path.join(__dirname, "..", "..", ".env");
  if (!fs.existsSync(envFile)) {
    return;
  }

  const lines = fs.readFileSync(envFile, "utf8").split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) {
      continue;
    }

    const separatorIndex = trimmed.indexOf("=");
    if (separatorIndex <= 0) {
      continue;
    }

    let key = trimmed.slice(0, separatorIndex).trim();
    key = key.replace(/^\uFEFF/, "");
    let value = trimmed.slice(separatorIndex + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    if (!process.env[key]) {
      process.env[key] = value;
    }
  }
}

/**
 * Parses the port value into the backend format.
 */
function parsePort(rawPort) {
  if (!rawPort) {
    return DEFAULT_PORT;
  }

  const value = Number(rawPort);
  if (!Number.isInteger(value) || value <= 0) {
    return DEFAULT_PORT;
  }

  return value;
}

/**
 * Parses the origins value into the backend format.
 */
function parseOrigins(rawOrigins) {
  if (!rawOrigins || rawOrigins.trim().length === 0) {
    return String(process.env.NODE_ENV ?? "").trim().toLowerCase() ===
      "production"
      ? []
      : true;
  }

  return rawOrigins
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);
}

loadDotEnv();

const env = {
  port: parsePort(process.env.PORT),
  corsOrigin: parseOrigins(process.env.CORS_ORIGIN),
};

module.exports = { env };
