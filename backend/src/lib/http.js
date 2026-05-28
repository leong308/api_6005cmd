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
      payload[field] === null ||
      payload[field] === undefined ||
      payload[field] === ""
    ) {
      missing.push(field);
    }
  }

  if (missing.length > 0) {
    throw new HttpError(400, "Missing required fields.", { missing });
  }
}

module.exports = {
  HttpError,
  assertRequiredFields,
};
