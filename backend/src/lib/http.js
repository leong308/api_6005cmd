/**
 * Shared HTTP helper utilities.
 *
 * This file defines the reusable `HttpError` class and request-body validation
 * helper used by controllers, services, middleware, and route modules.
 */
class HttpError extends Error {
  constructor(statusCode, message, details = null) {
    super(message);
    this.name = "HttpError";
    this.statusCode = statusCode;
    this.details = details;
  }
}

function assertRequiredFields(payload, requiredFields) {
  const missing = [];
  for (const field of requiredFields) {
    if (
      !Object.prototype.hasOwnProperty.call(payload, field) ||
      isBlankValue(payload[field])
    ) {
      missing.push(field);
    }
  }

  if (missing.length > 0) {
    throw new HttpError(400, "Missing required fields.", { missing });
  }
}

function assertProvidedFieldsNotEmpty(payload, fields) {
  const empty = [];
  for (const field of fields) {
    if (
      Object.prototype.hasOwnProperty.call(payload, field) &&
      isBlankValue(payload[field])
    ) {
      empty.push(field);
    }
  }

  if (empty.length > 0) {
    throw new HttpError(400, "Fields cannot be empty.", { empty });
  }
}

function isBlankValue(value) {
  return (
    value === null ||
    value === undefined ||
    (typeof value === "string" && value.trim() === "")
  );
}

module.exports = {
  HttpError,
  assertProvidedFieldsNotEmpty,
  assertRequiredFields,
};
