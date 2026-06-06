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
  getUserByPasswordResetTokenHash,
  getUserByVerificationTokenHash,
  markUserAppTourCompleted,
  markUserEmailVerified,
  setUserPasswordReset,
  setUserEmailVerification,
  updateUserPassword,
} = require("../data/repository");
const {
  comparePassword,
  createEmailVerificationToken,
  createPasswordResetToken,
  generateToken,
  hashPassword,
  hashToken,
} = require("../services/authService");
const {
  sendPasswordResetEmail,
  sendVerificationEmail,
} = require("../services/emailService");
const {
  createFirebaseUser,
  lookupFirebaseUser,
  sendFirebaseEmailVerification,
  sendFirebasePasswordReset,
  shouldUseFirebaseAuthEmail,
  signInFirebaseUser,
} = require("../services/firebaseAuthService");
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

    const password = String(req.body.password);
    const email = String(req.body.email);
    const name = String(req.body.name);

    // Hash the password before storing
    const hashedPassword = await hashPassword(password);
    const verification = createEmailVerificationToken();
    const useFirebaseEmail = shouldUseFirebaseAuthEmail();
    const firebaseAccount = useFirebaseEmail
      ? await createFirebaseAuthAccount({ email, password })
      : null;
    const firebaseProfile = firebaseAccount
      ? await lookupFirebaseUser(firebaseAccount.idToken)
      : null;
    const emailVerified = Boolean(firebaseProfile?.emailVerified);

    const user = await createUser({
      name,
      email,
      password: hashedPassword,
      emailVerified,
      emailVerifiedAt: emailVerified ? new Date().toISOString() : null,
      emailVerificationProvider: useFirebaseEmail ? "firebase" : "email",
      firebaseLocalId: firebaseAccount?.localId ?? null,
      emailVerificationTokenHash: useFirebaseEmail ? null : verification.tokenHash,
      emailVerificationExpiresAt: verification.expiresAt,
      firstLogin: true,
    });

    const emailResult = useFirebaseEmail
      ? emailVerified
        ? {
            delivered: true,
            provider: "firebase",
            expiresAt: verification.expiresAt,
            message: "Firebase account is already verified.",
          }
        : {
            ...(await sendFirebaseEmailVerification(firebaseAccount.idToken)),
            expiresAt: verification.expiresAt,
          }
      : await sendVerificationEmail({
          to: user.email,
          name: user.name,
          verificationUrl: buildVerificationUrl(req, verification.token),
          expiresAt: verification.expiresAt,
        });

    res.status(201).json({
      success: true,
      message: emailVerified
        ? "User registered. You can now log in."
        : "User registered. Please verify your email before logging in.",
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
    if (isFirebaseAuthUser(user) && shouldUseFirebaseAuthEmail()) {
      throw new HttpError(
        400,
        "Enter your email and password on the login page to resend a Firebase verification email.",
      );
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

authRouter.post("/forgot-password", async (req, res, next) => {
  try {
    assertRequiredFields(req.body, ["email"]);
    const message =
      "If an account exists for that email, a password reset link has been sent.";
    const user = await getUserByEmail(String(req.body.email));
    if (!user || !user.emailVerified) {
      return res.json({ success: true, message });
    }

    if (isFirebaseAuthUser(user) && shouldUseFirebaseAuthEmail()) {
      const emailResult = await sendFirebasePasswordReset(user.email);
      return res.json({
        success: true,
        message,
        passwordReset: emailResult,
      });
    }

    const reset = createPasswordResetToken();
    const updated = await setUserPasswordReset(user.id, reset);
    const resetUrl = buildPasswordResetUrl(req, reset.token);
    const emailResult = await sendPasswordResetEmail({
      to: updated.email,
      name: updated.name,
      resetUrl,
      expiresAt: reset.expiresAt,
    });

    return res.json({
      success: true,
      message,
      passwordReset: emailResult,
    });
  } catch (error) {
    next(error);
  }
});

authRouter.get("/reset-password", async (req, res, next) => {
  try {
    const token = String(req.query.token ?? "").trim();
    if (!token) {
      return sendPasswordResetResponse(req, res, {
        statusCode: 400,
        success: false,
        title: "Reset Link Missing",
        message:
          "The password reset link is missing its token. Please request a new password reset email.",
      });
    }

    const user = await getUserByPasswordResetTokenHash(hashToken(token));
    const validation = validatePasswordResetUser(user);
    if (!validation.valid) {
      return sendPasswordResetResponse(req, res, {
        statusCode: 400,
        success: false,
        title: validation.title,
        message: validation.message,
      });
    }

    return res
      .status(200)
      .type("html")
      .send(renderPasswordResetFormPage({ token }));
  } catch (error) {
    next(error);
  }
});

authRouter.post("/reset-password", async (req, res, next) => {
  try {
    assertRequiredFields(req.body, ["token", "password"]);
    const token = String(req.body.token ?? "").trim();
    const password = String(req.body.password ?? "");
    if (password.length < 8) {
      return sendPasswordResetResponse(req, res, {
        statusCode: 400,
        success: false,
        title: "Password Too Short",
        message: "Use a password with at least 8 characters.",
      });
    }

    const user = await getUserByPasswordResetTokenHash(hashToken(token));
    const validation = validatePasswordResetUser(user);
    if (!validation.valid) {
      return sendPasswordResetResponse(req, res, {
        statusCode: 400,
        success: false,
        title: validation.title,
        message: validation.message,
      });
    }

    const hashedPassword = await hashPassword(password);
    await updateUserPassword(user.id, hashedPassword);
    return sendPasswordResetResponse(req, res, {
      statusCode: 200,
      success: true,
      title: "Password Reset Complete",
      message: "Your password has been updated. You can now log in.",
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

    const authenticatedUser =
      isFirebaseAuthUser(user) && shouldUseFirebaseAuthEmail()
        ? await authenticateFirebaseBackedUser(user, String(req.body.password))
        : await authenticateLocalUser(user, String(req.body.password));

    const token = generateToken(authenticatedUser);

    res.json({
      success: true,
      message: "Login successful.",
      token,
      data: {
        id: authenticatedUser.id,
        name: authenticatedUser.name,
        email: authenticatedUser.email,
        emailVerified: authenticatedUser.emailVerified,
        firstLogin: authenticatedUser.firstLogin !== false,
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
        firstLogin: user.firstLogin !== false,
      },
    });
  } catch (error) {
    next(error);
  }
});

authRouter.post("/complete-tour", authMiddleware, async (req, res, next) => {
  try {
    const user = await markUserAppTourCompleted(req.user.id);
    if (!user) {
      throw new HttpError(404, "User not found.");
    }

    return res.json({
      success: true,
      message: "App tour marked complete.",
      data: {
        id: user.id,
        email: user.email,
        firstLogin: user.firstLogin !== false,
      },
    });
  } catch (error) {
    next(error);
  }
});

module.exports = { authRouter };

async function createFirebaseAuthAccount({ email, password }) {
  try {
    return await createFirebaseUser({ email, password });
  } catch (error) {
    if (isFirebaseError(error, "EMAIL_EXISTS")) {
      try {
        return await signInFirebaseUser({ email, password });
      } catch (_signInError) {
        throw new HttpError(
          409,
          "Email already exists. Use forgot password or log in with the existing password.",
        );
      }
    }
    throw error;
  }
}

async function authenticateLocalUser(user, password) {
  if (!user.emailVerified) {
    throw new HttpError(403, "Please verify your email before logging in.");
  }

  const isMatch = await comparePassword(password, user.password);
  if (!isMatch) {
    throw new HttpError(401, "Invalid credentials.");
  }

  return user;
}

async function authenticateFirebaseBackedUser(user, password) {
  let firebaseSession;
  try {
    firebaseSession = await signInFirebaseUser({
      email: user.email,
      password,
    });
  } catch (error) {
    if (
      isFirebaseError(error, "INVALID_LOGIN_CREDENTIALS") ||
      isFirebaseError(error, "INVALID_PASSWORD") ||
      isFirebaseError(error, "EMAIL_NOT_FOUND")
    ) {
      throw new HttpError(401, "Invalid credentials.");
    }
    throw error;
  }

  const firebaseUser = await lookupFirebaseUser(firebaseSession.idToken);
  if (!firebaseUser.emailVerified) {
    await sendFirebaseEmailVerification(firebaseSession.idToken);
    throw new HttpError(
      403,
      "Please verify your email before logging in. A new verification email has been sent.",
    );
  }

  if (!user.emailVerified) {
    const verifiedUser = await markUserEmailVerified(user.id);
    return verifiedUser || { ...user, emailVerified: true };
  }

  return user;
}

function isFirebaseAuthUser(user) {
  return user?.emailVerificationProvider === "firebase";
}

function isFirebaseError(error, code) {
  return String(error?.message ?? "").includes(code);
}

function buildVerificationUrl(req, token) {
  const configuredBase = String(process.env.PUBLIC_API_BASE_URL ?? "").trim();
  const baseUrl =
    configuredBase ||
    `${req.protocol}://${req.get("host")}`;
  return `${baseUrl.replace(/\/$/, "")}/api/auth/verify-email?token=${encodeURIComponent(token)}`;
}

function buildPasswordResetUrl(req, token) {
  const configuredBase = String(process.env.PUBLIC_API_BASE_URL ?? "").trim();
  const baseUrl = configuredBase || `${req.protocol}://${req.get("host")}`;
  return `${baseUrl.replace(/\/$/, "")}/api/auth/reset-password?token=${encodeURIComponent(token)}`;
}

function validatePasswordResetUser(user) {
  if (!user) {
    return {
      valid: false,
      title: "Reset Link Invalid",
      message:
        "This password reset link is invalid or has already been used.",
    };
  }

  const expiresAt = new Date(user.passwordResetExpiresAt ?? 0);
  if (Number.isNaN(expiresAt.getTime()) || expiresAt.getTime() < Date.now()) {
    return {
      valid: false,
      title: "Reset Link Expired",
      message: "This password reset link has expired. Please request a new one.",
    };
  }

  return { valid: true };
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

function sendPasswordResetResponse(
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
  const acceptHeader = String(req.get("accept") ?? "").toLowerCase();
  if (!acceptHeader || acceptHeader.trim() === "*/*") {
    return false;
  }
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

function renderPasswordResetFormPage({ token }) {
  const escapedToken = escapeAttribute(token);
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Reset Password · Smart Travel Planner</title>
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
      width: min(460px, 100%);
      padding: 30px;
      border: 1px solid rgba(37, 99, 235, 0.18);
      border-radius: 24px;
      background: rgba(255, 255, 255, 0.9);
      box-shadow: 0 22px 70px rgba(15, 23, 42, 0.12);
    }
    h1 {
      margin: 0;
      font-size: clamp(28px, 5vw, 36px);
      line-height: 1.1;
    }
    p {
      margin: 12px 0 22px;
      color: #64748b;
      line-height: 1.5;
    }
    label {
      display: block;
      margin-bottom: 8px;
      color: #334155;
      font-weight: 700;
    }
    input {
      width: 100%;
      min-height: 48px;
      padding: 12px 14px;
      border: 1px solid #cbd5e1;
      border-radius: 14px;
      font: inherit;
      outline: none;
    }
    input:focus {
      border-color: #3b82f6;
      box-shadow: 0 0 0 4px rgba(59, 130, 246, 0.14);
    }
    button {
      width: 100%;
      min-height: 48px;
      margin-top: 18px;
      border: 0;
      border-radius: 999px;
      background: #3b82f6;
      color: white;
      font: inherit;
      font-weight: 800;
      cursor: pointer;
      box-shadow: 0 10px 28px rgba(59, 130, 246, 0.26);
    }
  </style>
</head>
<body>
  <main>
    <h1>Reset Password</h1>
    <p>Enter a new password for your Smart Travel Planner account.</p>
    <form method="post" action="/api/auth/reset-password">
      <input type="hidden" name="token" value="${escapedToken}">
      <label for="password">New password</label>
      <input id="password" name="password" type="password" autocomplete="new-password" minlength="8" required autofocus>
      <button type="submit">Update Password</button>
    </form>
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
