const test = require("node:test");
const assert = require("node:assert/strict");

const store = require("../src/data/store");

test("does not reuse a local user ID after expired-account cleanup", () => {
  const first = store.createUser({
    name: "Expired User",
    email: "expired@example.test",
    password: "hash",
    emailVerificationExpiresAt: "2020-01-01T00:00:00.000Z",
  });
  const second = store.createUser({
    name: "Active User",
    email: "active@example.test",
    password: "hash",
    emailVerificationExpiresAt: "2100-01-01T00:00:00.000Z",
  });

  store.deleteExpiredUnverifiedUsers(new Date("2025-01-01T00:00:00.000Z"));

  const third = store.createUser({
    name: "New User",
    email: "new@example.test",
    password: "hash",
    emailVerificationExpiresAt: "2100-01-01T00:00:00.000Z",
  });

  assert.equal(first.id, "user_001");
  assert.equal(second.id, "user_002");
  assert.equal(third.id, "user_003");
});
