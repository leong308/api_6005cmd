const test = require("node:test");
const assert = require("node:assert/strict");

const { parsePort } = require("../src/config/env");

test("falls back for ports outside the TCP range", () => {
  assert.equal(parsePort("65535"), 65535);
  assert.equal(parsePort("65536"), 3000);
  assert.equal(parsePort("-1"), 3000);
  assert.equal(parsePort("not-a-port"), 3000);
});
