/**
 * Email delivery service.
 *
 * Uses a HTTPS email API when configured, which works on Render Free because it
 * avoids blocked outbound SMTP ports. SMTP is still supported for local or paid
 * hosting environments. In non-production, delivery failures return the action
 * link so development can continue without real email delivery.
 */
const nodemailer = require("nodemailer");

let transporterPromise = null;

/**
 * Sends the verification email message or response.
 */
async function sendVerificationEmail({ to, name, verificationUrl, expiresAt }) {
  return sendTransactionalEmail({
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
    expiresAt,
    fallbackUrl: verificationUrl,
    fallbackUrlKey: "devVerificationUrl",
    noProviderMessage:
      "Email provider is not configured. Use devVerificationUrl to verify locally.",
    failureMessage:
      "Email delivery failed. Use devVerificationUrl to verify locally.",
    successMessage: "Verification email sent.",
  });
}

/**
 * Sends the password reset email message or response.
 */
async function sendPasswordResetEmail({ to, name, resetUrl, expiresAt }) {
  return sendTransactionalEmail({
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
    expiresAt,
    fallbackUrl: resetUrl,
    fallbackUrlKey: "devResetUrl",
    noProviderMessage:
      "Email provider is not configured. Use devResetUrl to reset locally.",
    failureMessage: "Email delivery failed. Use devResetUrl to reset locally.",
    successMessage: "Password reset email sent.",
  });
}

/**
 * Sends the transactional email message or response.
 */
async function sendTransactionalEmail({
  to,
  subject,
  text,
  html,
  expiresAt,
  fallbackUrl,
  fallbackUrlKey,
  noProviderMessage,
  failureMessage,
  successMessage,
}) {
  try {
    const provider = readEmailProvider();

    if (
      provider === "resend" ||
      (provider === "auto" && isResendConfigured())
    ) {
      if (!isResendConfigured()) {
        throw new Error(
          "Resend email provider is selected but RESEND_API_KEY is missing.",
        );
      }

      const result = await sendWithResend({ to, subject, text, html });
      return {
        delivered: true,
        provider: "resend",
        expiresAt,
        message: successMessage,
        messageId: result.id,
      };
    }

    if (provider === "smtp" || (provider === "auto" && isSmtpConfigured())) {
      if (!isSmtpConfigured()) {
        throw new Error(
          "SMTP email provider is selected but SMTP settings are incomplete.",
        );
      }

      await sendWithSmtp({ to, subject, text, html });
      return {
        delivered: true,
        provider: "smtp",
        expiresAt,
        message: successMessage,
      };
    }

    if (!shouldUseDevelopmentFallback()) {
      throw new Error("Email provider is not configured.");
    }

    console.warn(
      `Email provider is not configured. Development link for ${to}: ${fallbackUrl}`,
    );
    return buildDevelopmentEmailResult({
      fallbackUrl,
      fallbackUrlKey,
      expiresAt,
      message: noProviderMessage,
    });
  } catch (error) {
    if (!shouldUseDevelopmentFallback()) {
      throw error;
    }

    console.warn(
      `Email delivery failed. Development link for ${to}: ${fallbackUrl}. Error: ${error.message}`,
    );
    return buildDevelopmentEmailResult({
      fallbackUrl,
      fallbackUrlKey,
      expiresAt,
      message: failureMessage,
      error: error.message,
    });
  }
}

/**
 * Sends the with resend message or response.
 */
async function sendWithResend({ to, subject, text, html }) {
  const response = await fetch(readResendApiUrl(), {
    method: "POST",
    headers: {
      Authorization: `Bearer ${readResendApiKey()}`,
      "Content-Type": "application/json",
      "User-Agent": "smart-travel-planner-backend/1.0",
    },
    body: JSON.stringify({
      from: readMailFrom(),
      to: [to],
      subject,
      text,
      html,
    }),
    signal: AbortSignal.timeout(readEmailRequestTimeoutMs()),
  });

  const responseBody = await response.text();
  const parsedBody = parseJson(responseBody);
  if (!response.ok) {
    const details =
      parsedBody?.message || parsedBody?.error || responseBody || response.statusText;
    throw new Error(`Resend email send failed (${response.status}): ${details}`);
  }

  return parsedBody || {};
}

/**
 * Sends the with smtp message or response.
 */
async function sendWithSmtp({ to, subject, text, html }) {
  const transporter = await getTransporter();
  await transporter.sendMail({
    from: readMailFrom(),
    to,
    subject,
    text,
    html,
  });
}

/**
 * Gets the transporter data.
 */
async function getTransporter() {
  if (!transporterPromise) {
    transporterPromise = Promise.resolve(
      nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port: Number(process.env.SMTP_PORT || 587),
        secure: String(process.env.SMTP_SECURE ?? "").toLowerCase() === "true",
        connectionTimeout: readEmailRequestTimeoutMs(),
        greetingTimeout: readEmailRequestTimeoutMs(),
        socketTimeout: readEmailRequestTimeoutMs(),
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

/**
 * Reads the email provider value from configuration or input.
 */
function readEmailProvider() {
  const provider = String(process.env.EMAIL_PROVIDER ?? "auto")
    .trim()
    .toLowerCase();
  if (["auto", "resend", "smtp"].includes(provider)) {
    return provider;
  }
  return "auto";
}

/**
 * Checks whether resend configured is true.
 */
function isResendConfigured() {
  return Boolean(readResendApiKey());
}

/**
 * Reads the resend api key value from configuration or input.
 */
function readResendApiKey() {
  return readNonPlaceholderEnv(
    "RESEND_API_KEY",
    "replace_with_your_resend_api_key",
    "your_resend_api_key_here",
  );
}

/**
 * Reads the resend api url value from configuration or input.
 */
function readResendApiUrl() {
  return String(process.env.RESEND_API_URL || "https://api.resend.com/emails").trim();
}

/**
 * Checks whether smtp configured is true.
 */
function isSmtpConfigured() {
  return Boolean(
    String(process.env.SMTP_HOST ?? "").trim() &&
      String(process.env.SMTP_USER ?? "").trim() &&
      String(process.env.SMTP_PASS ?? "").trim(),
  );
}

/**
 * Reads the mail from value from configuration or input.
 */
function readMailFrom() {
  return (
    String(process.env.MAIL_FROM ?? "").trim() ||
    String(process.env.SMTP_USER ?? "").trim() ||
    "Smart Trip Planner <onboarding@resend.dev>"
  );
}

/**
 * Reads the tls options value from configuration or input.
 */
function readTlsOptions() {
  const rejectUnauthorized = String(
    process.env.SMTP_TLS_REJECT_UNAUTHORIZED ?? "true",
  ).toLowerCase();
  if (rejectUnauthorized === "false") {
    return { rejectUnauthorized: false };
  }
  return undefined;
}

/**
 * Supports the should use development fallback backend flow.
 */
function shouldUseDevelopmentFallback() {
  const fallbackSetting = String(
    process.env.EMAIL_DEV_FALLBACK_ON_ERROR ??
      process.env.SMTP_DEV_FALLBACK_ON_ERROR ??
      "true",
  ).toLowerCase();
  return process.env.NODE_ENV !== "production" && fallbackSetting !== "false";
}

/**
 * Reads the email request timeout ms value from configuration or input.
 */
function readEmailRequestTimeoutMs() {
  const timeoutMs = Number(process.env.EMAIL_REQUEST_TIMEOUT_MS || 10000);
  if (!Number.isFinite(timeoutMs) || timeoutMs <= 0) {
    return 10000;
  }
  return timeoutMs;
}

/**
 * Reads the non placeholder env value from configuration or input.
 */
function readNonPlaceholderEnv(key, ...placeholders) {
  const value = String(process.env[key] ?? "").trim();
  if (!value) {
    return "";
  }

  const lowerValue = value.toLowerCase();
  if (placeholders.some((placeholder) => placeholder.toLowerCase() === lowerValue)) {
    return "";
  }

  return value;
}

/**
 * Builds the development email result payload.
 */
function buildDevelopmentEmailResult({
  fallbackUrl,
  fallbackUrlKey,
  expiresAt,
  message,
  error,
}) {
  return {
    delivered: false,
    [fallbackUrlKey]: fallbackUrl,
    expiresAt,
    message,
    ...(error ? { error } : {}),
  };
}

/**
 * Parses the json value into the backend format.
 */
function parseJson(value) {
  try {
    return JSON.parse(value);
  } catch (_error) {
    return null;
  }
}

/**
 * Supports the format expiry backend flow.
 */
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

/**
 * Escapes the html value for safe output.
 */
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
