const express = require("express");
const { HttpError, assertRequiredFields } = require("../lib/http");
const { getUserByEmail, getUserById, createUser } = require("../data/store");

const authRouter = express.Router();

function buildToken(userId) {
  return `mock-token-${userId}`;
}

function parseToken(authHeader) {
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return null;
  }

  const rawToken = authHeader.replace("Bearer ", "").trim();
  if (!rawToken.startsWith("mock-token-")) {
    return null;
  }

  const userId = rawToken.replace("mock-token-", "");
  return userId || null;
}

authRouter.post("/register", (req, res) => {
  assertRequiredFields(req.body, ["name", "email", "password"]);

  const existing = getUserByEmail(String(req.body.email));
  if (existing) {
    throw new HttpError(409, "Email already exists.");
  }

  const user = createUser(req.body);
  res.status(201).json({
    success: true,
    message: "User registered.",
    data: user,
  });
});

authRouter.post("/login", (req, res) => {
  assertRequiredFields(req.body, ["email", "password"]);

  const user = getUserByEmail(String(req.body.email));
  if (!user || user.password !== String(req.body.password)) {
    throw new HttpError(401, "Invalid credentials.");
  }

  res.json({
    success: true,
    token: buildToken(user.id),
    data: {
      id: user.id,
      name: user.name,
      email: user.email,
    },
  });
});

authRouter.get("/profile", (req, res) => {
  const userId = parseToken(req.headers.authorization);
  if (!userId) {
    throw new HttpError(401, "Missing or invalid bearer token.");
  }

  const user = getUserById(userId);
  if (!user) {
    throw new HttpError(404, "User not found.");
  }

  res.json({
    success: true,
    data: {
      id: user.id,
      name: user.name,
      email: user.email,
    },
  });
});

module.exports = { authRouter };
