const { HttpError } = require("./http");

/**
 * Normalizes a complete or partial trip payload and validates the merged trip.
 */
function normalizeTripPayload(payload, current = {}) {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    throw new HttpError(400, "Trip payload must be a JSON object.");
  }

  const normalized = {
    destinationName: normalizeRequiredText(
      readMergedValue(payload, current, "destinationName"),
      "destinationName",
    ),
    destinationCountry: normalizeRequiredText(
      readMergedValue(payload, current, "destinationCountry"),
      "destinationCountry",
    ),
    latitude: normalizeCoordinate(
      readMergedValue(payload, current, "latitude"),
      "latitude",
      -90,
      90,
    ),
    longitude: normalizeCoordinate(
      readMergedValue(payload, current, "longitude"),
      "longitude",
      -180,
      180,
    ),
    startDate: normalizeIsoDate(
      readMergedValue(payload, current, "startDate"),
      "startDate",
    ),
    endDate: normalizeIsoDate(
      readMergedValue(payload, current, "endDate"),
      "endDate",
    ),
    preferences: Object.prototype.hasOwnProperty.call(payload, "preferences")
      ? normalizePreferenceList(payload.preferences)
      : normalizePreferenceList(current.preferences ?? []),
    travelNotes: Object.prototype.hasOwnProperty.call(payload, "travelNotes")
      ? String(payload.travelNotes ?? "").trim()
      : String(current.travelNotes ?? "").trim(),
  };

  if (normalized.endDate < normalized.startDate) {
    throw new HttpError(
      400,
      "endDate must not be earlier than startDate.",
    );
  }

  return normalized;
}

function readMergedValue(payload, current, fieldName) {
  return Object.prototype.hasOwnProperty.call(payload, fieldName)
    ? payload[fieldName]
    : current[fieldName];
}

function normalizeRequiredText(value, fieldName) {
  const normalized = String(value ?? "").trim();
  if (!normalized) {
    throw new HttpError(400, `${fieldName} is required.`);
  }
  return normalized;
}

function normalizeCoordinate(value, fieldName, minimum, maximum) {
  if (
    value === null ||
    value === undefined ||
    (typeof value === "string" && value.trim() === "")
  ) {
    throw new HttpError(400, `${fieldName} is required.`);
  }
  const normalized = Number(value);
  if (
    !Number.isFinite(normalized) ||
    normalized < minimum ||
    normalized > maximum
  ) {
    throw new HttpError(
      400,
      `${fieldName} must be a valid number between ${minimum} and ${maximum}.`,
    );
  }
  return normalized;
}

function normalizeIsoDate(value, fieldName) {
  const normalized = String(value ?? "").trim();
  const match = normalized.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) {
    throw new HttpError(400, `${fieldName} must use YYYY-MM-DD format.`);
  }

  const year = Number(match[1]);
  const parsed = new Date(`${normalized}T00:00:00.000Z`);
  if (
    year < 1 ||
    Number.isNaN(parsed.getTime()) ||
    parsed.toISOString().slice(0, 10) !== normalized
  ) {
    throw new HttpError(400, `${fieldName} must be a valid calendar date.`);
  }
  return normalized;
}

function normalizePreferenceList(value) {
  if (!Array.isArray(value)) {
    throw new HttpError(400, "preferences must be an array.");
  }

  return [
    ...new Set(
      value
        .map((item) => String(item).trim().toLowerCase())
        .filter(Boolean),
    ),
  ];
}

module.exports = {
  normalizeTripPayload,
};
