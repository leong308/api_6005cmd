/**
 * Firebase Authentication REST client.
 *
 * Uses Google's HTTPS Identity Toolkit API to let Firebase send verification
 * and password reset emails. This avoids SMTP and custom-domain restrictions
 * for small deployments while the backend continues issuing its own JWTs.
 */
const FIREBASE_AUTH_BASE_URL = "https://identitytoolkit.googleapis.com/v1";

function isFirebaseAuthConfigured() {
  return Boolean(readFirebaseApiKey());
}

async function createFirebaseUser({ email, password }) {
  const data = await postFirebase("accounts:signUp", {
    email,
    password,
    returnSecureToken: true,
  });

  return {
    localId: data.localId,
    idToken: data.idToken,
    email: data.email,
  };
}

async function signInFirebaseUser({ email, password }) {
  const data = await postFirebase("accounts:signInWithPassword", {
    email,
    password,
    returnSecureToken: true,
  });

  return {
    localId: data.localId,
    idToken: data.idToken,
    email: data.email,
  };
}

async function lookupFirebaseUser(idToken) {
  const data = await postFirebase("accounts:lookup", { idToken });
  const user = Array.isArray(data.users) ? data.users[0] : null;
  if (!user) {
    throw new Error("Firebase user lookup returned no user.");
  }

  return {
    localId: user.localId,
    email: user.email,
    emailVerified: Boolean(user.emailVerified),
  };
}

async function sendFirebaseEmailVerification(idToken) {
  const data = await postFirebase("accounts:sendOobCode", {
    requestType: "VERIFY_EMAIL",
    idToken,
  });

  return {
    delivered: true,
    provider: "firebase",
    message: "Verification email sent by Firebase Authentication.",
    email: data.email,
  };
}

async function sendFirebasePasswordReset(email) {
  const data = await postFirebase("accounts:sendOobCode", {
    requestType: "PASSWORD_RESET",
    email,
  });

  return {
    delivered: true,
    provider: "firebase",
    message: "Password reset email sent by Firebase Authentication.",
    email: data.email,
  };
}

function shouldUseFirebaseAuthEmail() {
  return String(process.env.EMAIL_PROVIDER ?? "").trim().toLowerCase() === "firebase";
}

async function postFirebase(endpoint, body) {
  const apiKey = readFirebaseApiKey();
  if (!apiKey) {
    throw new Error("FIREBASE_AUTH_API_KEY is required for Firebase Auth email.");
  }

  const response = await fetch(
    `${FIREBASE_AUTH_BASE_URL}/${endpoint}?key=${encodeURIComponent(apiKey)}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "User-Agent": "smart-travel-planner-backend/1.0",
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(readFirebaseRequestTimeoutMs()),
    },
  );

  const responseBody = await response.text();
  const parsedBody = parseJson(responseBody);
  if (!response.ok) {
    const code = parsedBody?.error?.message || response.statusText;
    throw new Error(`Firebase Auth failed (${response.status}): ${code}`);
  }

  return parsedBody || {};
}

function readFirebaseApiKey() {
  const value = String(process.env.FIREBASE_AUTH_API_KEY ?? "").trim();
  if (
    !value ||
    value === "replace_with_your_firebase_web_api_key" ||
    value === "your_firebase_web_api_key_here"
  ) {
    return "";
  }
  return value;
}

function readFirebaseRequestTimeoutMs() {
  const timeoutMs = Number(
    process.env.FIREBASE_AUTH_REQUEST_TIMEOUT_MS ||
      process.env.EMAIL_REQUEST_TIMEOUT_MS ||
      10000,
  );
  if (!Number.isFinite(timeoutMs) || timeoutMs <= 0) {
    return 10000;
  }
  return timeoutMs;
}

function parseJson(value) {
  try {
    return JSON.parse(value);
  } catch (_error) {
    return null;
  }
}

module.exports = {
  createFirebaseUser,
  isFirebaseAuthConfigured,
  lookupFirebaseUser,
  sendFirebaseEmailVerification,
  sendFirebasePasswordReset,
  shouldUseFirebaseAuthEmail,
  signInFirebaseUser,
};
