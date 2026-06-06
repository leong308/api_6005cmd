/**
 * Email delivery service.
 *
 * Uses SMTP settings from backend/.env. When SMTP is not configured, the
 * service logs and returns the verification link so local development can still
 * complete the signup flow.
 */
const nodemailer = require("nodemailer");

let transporterPromise = null;

async function sendVerificationEmail({ to, name, verificationUrl, expiresAt }) {
  if (!isSmtpConfigured()) {
    console.warn(
      `SMTP is not configured. Development verification link for ${to}: ${verificationUrl}`,
    );
    return {
      delivered: false,
      devVerificationUrl: verificationUrl,
      expiresAt,
      message:
        "SMTP is not configured. Use devVerificationUrl to verify locally.",
    };
  }

  const transporter = await getTransporter();
  try {
    await transporter.sendMail({
      from: readMailFrom(),
      to,
      subject: "Verify your Smart Travel Planner account",
      text: [
        `Hi ${name || "there"},`,
        "",
        "Please verify your Smart Travel Planner account by opening this link:",
        verificationUrl,
        "",
        `This link expires ${formatExpiry(expiresAt)}.`,
      ].join("\n"),
      html: [
        `<p>Hi ${escapeHtml(name || "there")},</p>`,
        "<p>Please verify your Smart Travel Planner account by opening this link:</p>",
        `<p><a href="${verificationUrl}">Verify email address</a></p>`,
        `<p>This link expires ${escapeHtml(formatExpiry(expiresAt))}.</p>`,
      ].join(""),
    });
  } catch (error) {
    if (!shouldUseDevelopmentFallback()) {
      throw error;
    }

    console.warn(
      `SMTP delivery failed. Development verification link for ${to}: ${verificationUrl}. Error: ${error.message}`,
    );
    return {
      delivered: false,
      devVerificationUrl: verificationUrl,
      expiresAt,
      message:
        "SMTP delivery failed. Use devVerificationUrl to verify locally.",
      error: error.message,
    };
  }

  return {
    delivered: true,
    expiresAt,
    message: "Verification email sent.",
  };
}

async function sendPasswordResetEmail({ to, name, resetUrl, expiresAt }) {
  if (!isSmtpConfigured()) {
    console.warn(
      `SMTP is not configured. Development password reset link for ${to}: ${resetUrl}`,
    );
    return {
      delivered: false,
      devResetUrl: resetUrl,
      expiresAt,
      message: "SMTP is not configured. Use devResetUrl to reset locally.",
    };
  }

  const transporter = await getTransporter();
  try {
    await transporter.sendMail({
      from: readMailFrom(),
      to,
      subject: "Reset your Smart Travel Planner password",
      text: [
        `Hi ${name || "there"},`,
        "",
        "Open this link to reset your Smart Travel Planner password:",
        resetUrl,
        "",
        `This link expires ${formatExpiry(expiresAt)}.`,
        "If you did not request this, ignore this email.",
      ].join("\n"),
      html: [
        `<p>Hi ${escapeHtml(name || "there")},</p>`,
        "<p>Open this link to reset your Smart Travel Planner password:</p>",
        `<p><a href="${resetUrl}">Reset password</a></p>`,
        `<p>This link expires ${escapeHtml(formatExpiry(expiresAt))}.</p>`,
        "<p>If you did not request this, ignore this email.</p>",
      ].join(""),
    });
  } catch (error) {
    if (!shouldUseDevelopmentFallback()) {
      throw error;
    }

    console.warn(
      `SMTP delivery failed. Development password reset link for ${to}: ${resetUrl}. Error: ${error.message}`,
    );
    return {
      delivered: false,
      devResetUrl: resetUrl,
      expiresAt,
      message: "SMTP delivery failed. Use devResetUrl to reset locally.",
      error: error.message,
    };
  }

  return {
    delivered: true,
    expiresAt,
    message: "Password reset email sent.",
  };
}

async function getTransporter() {
  if (!transporterPromise) {
    transporterPromise = Promise.resolve(
      nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port: Number(process.env.SMTP_PORT || 587),
        secure: String(process.env.SMTP_SECURE ?? "").toLowerCase() === "true",
        tls: readTlsOptions(),
        auth: {
          user: process.env.SMTP_USER,
          pass: process.env.SMTP_PASS,
        },
      }),
    );
  }
  return transporterPromise;
}

function isSmtpConfigured() {
  return Boolean(
    String(process.env.SMTP_HOST ?? "").trim() &&
      String(process.env.SMTP_USER ?? "").trim() &&
      String(process.env.SMTP_PASS ?? "").trim(),
  );
}

function readMailFrom() {
  return (
    String(process.env.MAIL_FROM ?? "").trim() ||
    String(process.env.SMTP_USER ?? "").trim()
  );
}

function readTlsOptions() {
  const rejectUnauthorized = String(
    process.env.SMTP_TLS_REJECT_UNAUTHORIZED ?? "true",
  ).toLowerCase();
  if (rejectUnauthorized === "false") {
    return { rejectUnauthorized: false };
  }
  return undefined;
}

function shouldUseDevelopmentFallback() {
  const fallbackSetting = String(
    process.env.SMTP_DEV_FALLBACK_ON_ERROR ?? "true",
  ).toLowerCase();
  return process.env.NODE_ENV !== "production" && fallbackSetting !== "false";
}

function formatExpiry(expiresAt) {
  const expiresTime = Date.parse(expiresAt ?? "");
  if (!Number.isFinite(expiresTime)) {
    return "in 2 hours";
  }

  const durationMs = Math.max(0, expiresTime - Date.now());
  const hours = Math.round(durationMs / (60 * 60 * 1000));
  if (hours >= 1) {
    return `in ${hours} hour${hours === 1 ? "" : "s"}`;
  }

  const minutes = Math.max(1, Math.round(durationMs / (60 * 1000)));
  return `in ${minutes} minute${minutes === 1 ? "" : "s"}`;
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

module.exports = {
  sendPasswordResetEmail,
  sendVerificationEmail,
};
