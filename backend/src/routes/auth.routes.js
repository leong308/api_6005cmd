/**
 * Authentication routes.
 *
 * This file defines optional account endpoints for register, login, and profile
 * lookup. Password hashing and token logic are delegated to `authService`.
 */
const express = require("express");
const { HttpError, assertRequiredFields } = require("../lib/http");
const {
  createUser,
  getUserByEmail,
  getUserById,
  getUserByVerificationTokenHash,
  markUserEmailVerified,
  setUserEmailVerification,
} = require("../data/repository");
const {
  comparePassword,
  createEmailVerificationToken,
  generateToken,
  hashPassword,
  hashToken,
} = require("../services/authService");
const { sendVerificationEmail } = require("../services/emailService");
const { authMiddleware } = require("../middleware/authMiddleware");

const authRouter = express.Router();

/**
 * POST /api/auth/register
 * Creates a new unverified user and emails a verification link.
 */
authRouter.post("/register", async (req, res, next) => {
  try {
    assertRequiredFields(req.body, ["name", "email", "password"]);

    const existing = await getUserByEmail(String(req.body.email));
    if (existing) {
      throw new HttpError(409, "Email already exists.");
    }

    // Hash the password before storing
    const hashedPassword = await hashPassword(String(req.body.password));
    const verification = createEmailVerificationToken();

    const user = await createUser({
      name: req.body.name,
      email: req.body.email,
      password: hashedPassword,
      emailVerified: false,
      emailVerificationTokenHash: verification.tokenHash,
      emailVerificationExpiresAt: verification.expiresAt,
    });

    const verificationUrl = buildVerificationUrl(req, verification.token);
    const emailResult = await sendVerificationEmail({
      to: user.email,
      name: user.name,
      verificationUrl,
    });

    res.status(201).json({
      success: true,
      message:
        "User registered. Please verify your email before logging in.",
      emailVerification: emailResult,
      data: user,
    });
  } catch (error) {
    next(error);
  }
});

authRouter.get("/verify-email", async (req, res, next) => {
  try {
    const token = String(req.query.token ?? "").trim();
    if (!token) {
      throw new HttpError(400, "Verification token is required.");
    }

    const user = await getUserByVerificationTokenHash(hashToken(token));
    if (!user) {
      throw new HttpError(400, "Verification token is invalid.");
    }

    const expiresAt = new Date(user.emailVerificationExpiresAt ?? 0);
    if (Number.isNaN(expiresAt.getTime()) || expiresAt.getTime() < Date.now()) {
      throw new HttpError(400, "Verification token has expired.");
    }

    const verified = await markUserEmailVerified(user.id);
    return res.json({
      success: true,
      message: "Email verified. You can now log in.",
      data: verified,
    });
  } catch (error) {
    next(error);
  }
});

authRouter.post("/resend-verification", async (req, res, next) => {
  try {
    assertRequiredFields(req.body, ["email"]);
    const user = await getUserByEmail(String(req.body.email));
    if (!user) {
      throw new HttpError(404, "User not found.");
    }
    if (user.emailVerified) {
      throw new HttpError(409, "Email is already verified.");
    }

    const verification = createEmailVerificationToken();
    const updated = await setUserEmailVerification(user.id, verification);
    const verificationUrl = buildVerificationUrl(req, verification.token);
    const emailResult = await sendVerificationEmail({
      to: updated.email,
      name: updated.name,
      verificationUrl,
    });

    return res.json({
      success: true,
      message: "Verification email sent.",
      emailVerification: emailResult,
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

    const user = await getUserByEmail(String(req.body.email));
    if (!user) {
      throw new HttpError(401, "Invalid credentials.");
    }
    if (!user.emailVerified) {
      throw new HttpError(403, "Please verify your email before logging in.");
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
        emailVerified: user.emailVerified,
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
authRouter.get("/profile", authMiddleware, async (req, res, next) => {
  try {
    const user = await getUserById(req.user.id);
    if (!user) {
      throw new HttpError(404, "User not found.");
    }

    res.json({
      success: true,
      data: {
        id: user.id,
        name: user.name,
        email: user.email,
        emailVerified: user.emailVerified,
      },
    });
  } catch (error) {
    next(error);
  }
});

module.exports = { authRouter };

function buildVerificationUrl(req, token) {
  const configuredBase = String(process.env.PUBLIC_API_BASE_URL ?? "").trim();
  const baseUrl =
    configuredBase ||
    `${req.protocol}://${req.get("host")}`;
  return `${baseUrl.replace(/\/$/, "")}/api/auth/verify-email?token=${encodeURIComponent(token)}`;
}
