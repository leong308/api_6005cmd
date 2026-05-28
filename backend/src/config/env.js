const DEFAULT_PORT = 3000;

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

function parseOrigins(rawOrigins) {
  if (!rawOrigins || rawOrigins.trim().length === 0) {
    return true;
  }

  return rawOrigins
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);
}

const env = {
  port: parsePort(process.env.PORT),
  corsOrigin: parseOrigins(process.env.CORS_ORIGIN),
};

module.exports = { env };
