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
const {
  cleanupExpiredUnverifiedUsers,
} = require("../services/unverifiedUserCleanupService");
const { authMiddleware } = require("../middleware/authMiddleware");

const authRouter = express.Router();

/**
 * POST /api/auth/register
 * Creates a new unverified user and emails a verification link.
 */
authRouter.post("/register", async (req, res, next) => {
  try {
    await cleanupExpiredUnverifiedUsers();
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
      expiresAt: verification.expiresAt,
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
      return sendVerificationResponse(req, res, {
        statusCode: 400,
        success: false,
        title: "Verification Link Missing",
        message:
          "The email verification link is missing its token. Please request a new verification email.",
      });
    }

    const user = await getUserByVerificationTokenHash(hashToken(token));
    if (!user) {
      return sendVerificationResponse(req, res, {
        statusCode: 400,
        success: false,
        title: "Verification Link Invalid",
        message:
          "This verification link is invalid or the account has already been verified.",
      });
    }

    const expiresAt = new Date(user.emailVerificationExpiresAt ?? 0);
    if (Number.isNaN(expiresAt.getTime()) || expiresAt.getTime() < Date.now()) {
      await cleanupExpiredUnverifiedUsers();
      return sendVerificationResponse(req, res, {
        statusCode: 400,
        success: false,
        title: "Verification Link Expired",
        message:
          "This verification link has expired. Unverified accounts are automatically deleted after 2 hours, so please sign up again.",
      });
    }

    const verified = await markUserEmailVerified(user.id);
    return sendVerificationResponse(req, res, {
      statusCode: 200,
      success: true,
      title: "Email Verified",
      message: "Email verified. You can now log in.",
      data: verified,
    });
  } catch (error) {
    next(error);
  }
});

authRouter.post("/resend-verification", async (req, res, next) => {
  try {
    await cleanupExpiredUnverifiedUsers();
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
      expiresAt: verification.expiresAt,
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
    await cleanupExpiredUnverifiedUsers();
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

function sendVerificationResponse(
  req,
  res,
  { statusCode, success, title, message, data = null },
) {
  if (!prefersHtml(req)) {
    return res.status(statusCode).json({
      success,
      message,
      data,
    });
  }

  return res
    .status(statusCode)
    .type("html")
    .send(renderVerificationPage({ success, title, message }));
}

function prefersHtml(req) {
  const preferred = req.accepts(["html", "json"]);
  return preferred === "html";
}

function renderVerificationPage({ success, title, message }) {
  const appUrl = String(process.env.PUBLIC_APP_BASE_URL ?? "").trim();
  const escapedTitle = escapeHtml(title);
  const escapedMessage = escapeHtml(message);
  const statusClass = success ? "success" : "error";
  const icon = success ? "✓" : "!";
  const action = appUrl
    ? `<a class="button" href="${escapeAttribute(appUrl)}">Return to app</a>`
    : '<p class="hint">You can close this tab and return to Smart Travel Planner.</p>';

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapedTitle} · Smart Travel Planner</title>
  <style>
    :root {
      color-scheme: light;
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: linear-gradient(135deg, #eaf4ff, #eefbf6);
      color: #1f2937;
    }
    * { box-sizing: border-box; }
    body {
      min-height: 100vh;
      margin: 0;
      display: grid;
      place-items: center;
      padding: 24px;
    }
    main {
      width: min(520px, 100%);
      padding: 32px;
      border: 1px solid rgba(37, 99, 235, 0.18);
      border-radius: 24px;
      background: rgba(255, 255, 255, 0.88);
      box-shadow: 0 22px 70px rgba(15, 23, 42, 0.12);
      text-align: center;
    }
    .icon {
      width: 72px;
      height: 72px;
      margin: 0 auto 18px;
      display: grid;
      place-items: center;
      border-radius: 999px;
      font-size: 38px;
      font-weight: 800;
    }
    .success .icon {
      background: rgba(16, 185, 129, 0.14);
      color: #059669;
    }
    .error .icon {
      background: rgba(239, 68, 68, 0.12);
      color: #ef4444;
    }
    h1 {
      margin: 0;
      font-size: clamp(28px, 5vw, 38px);
      line-height: 1.1;
    }
    p {
      margin: 14px 0 0;
      color: #64748b;
      font-size: 16px;
      line-height: 1.55;
    }
    .button {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      margin-top: 24px;
      padding: 12px 18px;
      min-width: 160px;
      border-radius: 999px;
      background: #3b82f6;
      color: white;
      text-decoration: none;
      font-weight: 700;
      box-shadow: 0 10px 28px rgba(59, 130, 246, 0.26);
    }
    .hint {
      margin-top: 22px;
      font-size: 14px;
    }
  </style>
</head>
<body>
  <main class="${statusClass}">
    <div class="icon" aria-hidden="true">${icon}</div>
    <h1>${escapedTitle}</h1>
    <p>${escapedMessage}</p>
    ${action}
  </main>
</body>
</html>`;
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function escapeAttribute(value) {
  return escapeHtml(value).replace(/`/g, "&#096;");
}
