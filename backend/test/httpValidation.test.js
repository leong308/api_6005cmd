const test = require("node:test");
const assert = require("node:assert/strict");

const {
  HttpError,
  assertProvidedFieldsNotEmpty,
  assertRequiredFields,
} = require("../src/lib/http");

test("rejects non-object request bodies with a client error", () => {
  for (const payload of [null, [], "text", 42]) {
    assert.throws(
      () => assertRequiredFields(payload, ["name"]),
      (error) =>
        error instanceof HttpError &&
        error.statusCode === 400 &&
        error.message.includes("JSON object"),
    );
    assert.throws(
      () => assertProvidedFieldsNotEmpty(payload, ["name"]),
      (error) => error instanceof HttpError && error.statusCode === 400,
    );
  }
});
