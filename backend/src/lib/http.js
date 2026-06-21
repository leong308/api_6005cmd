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

/**
 * Asserts that the required fields input is valid.
 */
function assertRequiredFields(payload, requiredFields) {
  assertJsonObject(payload);
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

/**
 * Asserts that the provided fields not empty input is valid.
 */
function assertProvidedFieldsNotEmpty(payload, fields) {
  assertJsonObject(payload);
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

/**
 * Rejects null, arrays, and primitive request bodies before field validation.
 */
function assertJsonObject(payload) {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    throw new HttpError(400, "Request body must be a JSON object.");
  }
}

/**
 * Checks whether blank value is true.
 */
function isBlankValue(value) {
  return (
    value === null ||
    value === undefined ||
    (typeof value === "string" && value.trim() === "")
  );
}

module.exports = {
  HttpError,
  assertJsonObject,
  assertProvidedFieldsNotEmpty,
  assertRequiredFields,
};
