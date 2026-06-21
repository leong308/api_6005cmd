const test = require("node:test");
const assert = require("node:assert/strict");

const { HttpError } = require("../src/lib/http");
const { decodePolyline } = require("../src/services/routeService");

test("decodes a valid Google polyline", () => {
  assert.deepEqual(decodePolyline("_p~iF~ps|U_ulLnnqC_mqNvxq`@"), [
    { latitude: 38.5, longitude: -120.2 },
    { latitude: 40.7, longitude: -120.95 },
    { latitude: 43.252, longitude: -126.453 },
  ]);
});

test("rejects truncated Google polylines instead of drawing bogus points", () => {
  assert.throws(
    () => decodePolyline("_"),
    (error) =>
      error instanceof HttpError &&
      error.statusCode === 502 &&
      error.message.includes("truncated"),
  );
});
