const test = require("node:test");
const assert = require("node:assert/strict");

test("serializes concurrent Nominatim requests to respect rate limits", async () => {
  const originalFetch = global.fetch;
  const callTimes = [];
  global.fetch = async () => {
    callTimes.push(Date.now());
    return {
      ok: true,
      json: async () => ({
        address: { country: "Test Country" },
        display_name: "Test Country",
      }),
    };
  };

  const { reverseGeocode } = require("../src/services/reverseGeocodeService");
  try {
    await Promise.all([
      reverseGeocode(1.11111, 101.11111),
      reverseGeocode(2.22222, 102.22222),
    ]);

    assert.equal(callTimes.length, 2);
    assert.ok(
      callTimes[1] - callTimes[0] >= 1000,
      `Expected at least 1000ms between requests, got ${callTimes[1] - callTimes[0]}ms`,
    );
  } finally {
    global.fetch = originalFetch;
  }
});
