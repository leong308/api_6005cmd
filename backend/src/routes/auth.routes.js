/**
 * Authentication routes.
 *
 * This file defines optional account endpoints for register, login, and profile
 * lookup. Password hashing and token logic are delegated to `authService`.
 */
const express = require("express");
const { HttpError, assertRequiredFields } = require("../lib/http");
const { getUserByEmail, getUserById, createUser } = require("../data/store");
const { hashPassword, comparePassword, generateToken } = require("../services/authService");
const { authMiddleware } = require("../middleware/authMiddleware");

const authRouter = express.Router();

/**
 * POST /api/auth/register
 * Creates a new user with a bcrypt-hashed password and returns a JWT token.
 */
authRouter.post("/register", async (req, res, next) => {
  try {
    assertRequiredFields(req.body, ["name", "email", "password"]);

    const existing = getUserByEmail(String(req.body.email));
    if (existing) {
      throw new HttpError(409, "Email already exists.");
    }

    // Hash the password before storing
    const hashedPassword = await hashPassword(String(req.body.password));

    const user = createUser({
      name: req.body.name,
      email: req.body.email,
      password: hashedPassword,
    });

    // Generate JWT token for immediate login after registration
    const token = generateToken(user);

    res.status(201).json({
      success: true,
      message: "User registered successfully.",
      token,
      data: user,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/auth/login
 * Validates credentials using bcrypt and returns a JWT token.
 */
authRouter.post("/login", async (req, res, next) => {
  try {
    assertRequiredFields(req.body, ["email", "password"]);

    const user = getUserByEmail(String(req.body.email));
    if (!user) {
      throw new HttpError(401, "Invalid credentials.");
    }

    // Compare password with bcrypt hash
    const isMatch = await comparePassword(String(req.body.password), user.password);
    if (!isMatch) {
      throw new HttpError(401, "Invalid credentials.");
    }

    const token = generateToken(user);

    res.json({
      success: true,
      message: "Login successful.",
      token,
      data: {
        id: user.id,
        name: user.name,
        email: user.email,
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/auth/profile
 * Protected route — requires a valid JWT Bearer token.
 * Returns the authenticated user's profile.
 */
authRouter.get("/profile", authMiddleware, (req, res, next) => {
  try {
    const user = getUserById(req.user.id);
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
  } catch (error) {
    next(error);
  }
});

module.exports = { authRouter };
