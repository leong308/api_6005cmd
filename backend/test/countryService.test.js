const test = require("node:test");
const assert = require("node:assert/strict");

const { HttpError } = require("../src/lib/http");
const countryService = require("../src/services/countryService");

test("reports malformed country-provider JSON as a gateway error", async () => {
  const originalFetch = global.fetch;
  global.fetch = async () => ({
    ok: true,
    json: async () => {
      throw new SyntaxError("bad json");
    },
  });

  try {
    await assert.rejects(
      countryService.fetchCountryDataByCode("MY"),
      (error) =>
        error instanceof HttpError &&
        error.statusCode === 502 &&
        error.message.includes("malformed JSON"),
    );
  } finally {
    global.fetch = originalFetch;
  }
});

test("reports country-provider timeouts without hanging the request", async () => {
  const originalFetch = global.fetch;
  global.fetch = async () => {
    const error = new Error("timed out");
    error.name = "TimeoutError";
    throw error;
  };

  try {
    await assert.rejects(
      countryService.fetchCountryDataByCode("MY"),
      (error) =>
        error instanceof HttpError &&
        error.statusCode === 504 &&
        error.message.includes("timed out"),
    );
  } finally {
    global.fetch = originalFetch;
  }
});
