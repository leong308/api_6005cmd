/**
 * Email delivery service.
 *
 * Uses SMTP settings from backend/.env. When SMTP is not configured, the
 * service logs and returns the verification link so local development can still
 * complete the signup flow.
 */
const nodemailer = require("nodemailer");

let transporterPromise = null;

async function sendVerificationEmail({ to, name, verificationUrl }) {
  if (!isSmtpConfigured()) {
    console.warn(
      `SMTP is not configured. Development verification link for ${to}: ${verificationUrl}`,
    );
    return {
      delivered: false,
      devVerificationUrl: verificationUrl,
      message:
        "SMTP is not configured. Use devVerificationUrl to verify locally.",
    };
  }

  const transporter = await getTransporter();
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
      "This link expires in 24 hours.",
    ].join("\n"),
    html: [
      `<p>Hi ${escapeHtml(name || "there")},</p>`,
      "<p>Please verify your Smart Travel Planner account by opening this link:</p>",
      `<p><a href="${verificationUrl}">Verify email address</a></p>`,
      "<p>This link expires in 24 hours.</p>",
    ].join(""),
  });

  return {
    delivered: true,
    message: "Verification email sent.",
  };
}

async function getTransporter() {
  if (!transporterPromise) {
    transporterPromise = Promise.resolve(
      nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port: Number(process.env.SMTP_PORT || 587),
        secure: String(process.env.SMTP_SECURE ?? "").toLowerCase() === "true",
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

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

module.exports = {
  sendVerificationEmail,
};
