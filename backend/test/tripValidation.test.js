const test = require("node:test");
const assert = require("node:assert/strict");

const { HttpError } = require("../src/lib/http");
const { normalizeTripPayload } = require("../src/lib/tripValidation");

const validTrip = {
  destinationName: "Tokyo",
  destinationCountry: "Japan",
  latitude: 35.6762,
  longitude: 139.6503,
  startDate: "2026-07-12",
  endDate: "2026-07-18",
  preferences: ["Food", " food ", "culture"],
  travelNotes: "  Try local restaurants.  ",
};

test("normalizes a valid trip payload", () => {
  assert.deepEqual(normalizeTripPayload(validTrip), {
    ...validTrip,
    preferences: ["food", "culture"],
    travelNotes: "Try local restaurants.",
  });
});

test("rejects invalid coordinates and date ranges", () => {
  assert.throws(
    () => normalizeTripPayload({ ...validTrip, latitude: 91 }),
    (error) =>
      error instanceof HttpError &&
      error.statusCode === 400 &&
      error.message.includes("latitude"),
  );
  assert.throws(
    () => normalizeTripPayload({ ...validTrip, longitude: null }),
    (error) =>
      error instanceof HttpError &&
      error.statusCode === 400 &&
      error.message.includes("longitude"),
  );
  assert.throws(
    () =>
      normalizeTripPayload({
        ...validTrip,
        startDate: "2026-07-20",
        endDate: "2026-07-18",
      }),
    (error) =>
      error instanceof HttpError &&
      error.statusCode === 400 &&
      error.message.includes("endDate"),
  );
});

test("validates the complete merged payload during partial updates", () => {
  assert.throws(
    () => normalizeTripPayload({ startDate: "2026-08-01" }, validTrip),
    (error) =>
      error instanceof HttpError &&
      error.statusCode === 400 &&
      error.message.includes("endDate"),
  );
});
