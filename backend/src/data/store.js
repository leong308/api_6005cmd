/**
 * Lightweight application data store.
 *
 * This file is the backend's simple data layer. It keeps trips/users in memory,
 * persists trips to `backend/.data/trips.json`, creates generated trip IDs, and
 * exposes CRUD helper functions used by the route modules.
 */
const legacySeedTrips = [
  {
    id: "trip_001",
    destinationName: "Tokyo",
    destinationCountry: "Japan",
    latitude: 35.6762,
    longitude: 139.6503,
    startDate: "2026-07-12",
    endDate: "2026-07-18",
    preferences: ["culture", "food"],
    travelNotes: "Visit cultural places and try local restaurants.",
  },
  {
    id: "trip_002",
    destinationName: "Bangkok",
    destinationCountry: "Thailand",
    latitude: 13.7563,
    longitude: 100.5018,
    startDate: "2026-08-04",
    endDate: "2026-08-10",
    preferences: ["shopping", "food"],
    travelNotes: "Street food crawl and night market visits.",
  },
  {
    id: "trip_003",
    destinationName: "Seoul",
    destinationCountry: "South Korea",
    latitude: 37.5665,
    longitude: 126.978,
    startDate: "2026-09-01",
    endDate: "2026-09-07",
    preferences: ["culture", "family"],
    travelNotes: "Palaces, museums, and family-friendly attractions.",
  },
];

const seedTrips = [];
const seedSummaryByTrip = {};

const fs = require("fs");
const path = require("path");

const runtimeDataDir = path.join(__dirname, "..", "..", ".data");
const tripsFile = path.join(runtimeDataDir, "trips.json");

const seedUsers = [];

let trips = loadTrips();
let summaryByTrip = deepClone(seedSummaryByTrip);
let users = deepClone(seedUsers);

function deepClone(value) {
  return JSON.parse(JSON.stringify(value));
}

function loadTrips() {
  try {
    if (!fs.existsSync(tripsFile)) {
      return deepClone(seedTrips);
    }

    const parsed = JSON.parse(fs.readFileSync(tripsFile, "utf8"));
    if (Array.isArray(parsed)) {
      const tripsWithoutLegacySeeds = parsed.filter((trip) => !isLegacySeedTrip(trip));
      if (tripsWithoutLegacySeeds.length !== parsed.length) {
        writeTrips(tripsWithoutLegacySeeds);
      }
      return tripsWithoutLegacySeeds;
    }
  } catch (error) {
    console.warn(`Could not load persisted trips. Using seed data. ${error.message}`);
  }

  return deepClone(seedTrips);
}

function isLegacySeedTrip(trip) {
  return legacySeedTrips.some(
    (seed) =>
      trip?.id === seed.id &&
      trip?.destinationName === seed.destinationName &&
      trip?.destinationCountry === seed.destinationCountry &&
      trip?.startDate === seed.startDate &&
      trip?.endDate === seed.endDate,
  );
}

function persistTrips() {
  writeTrips(trips);
}

function writeTrips(nextTrips) {
  fs.mkdirSync(runtimeDataDir, { recursive: true });
  fs.writeFileSync(tripsFile, JSON.stringify(nextTrips, null, 2));
}

function generateTripId() {
  const maxNumber = trips.reduce((max, trip) => {
    const value = Number(trip.id.replace("trip_", ""));
    if (Number.isNaN(value)) {
      return max;
    }
    return Math.max(max, value);
  }, 0);
  return `trip_${String(maxNumber + 1).padStart(3, "0")}`;
}

function listTrips() {
  return deepClone(trips);
}

function getTripById(id) {
  const trip = trips.find((item) => item.id === id);
  return trip ? deepClone(trip) : null;
}

function createTrip(payload) {
  const created = {
    id: generateTripId(),
    ownerUserId: payload.ownerUserId ? String(payload.ownerUserId) : null,
    destinationName: String(payload.destinationName).trim(),
    destinationCountry: String(payload.destinationCountry).trim(),
    latitude: Number(payload.latitude),
    longitude: Number(payload.longitude),
    startDate: String(payload.startDate),
    endDate: String(payload.endDate),
    preferences: Array.isArray(payload.preferences)
      ? payload.preferences.map((value) => String(value))
      : [],
    travelNotes: String(payload.travelNotes ?? ""),
  };

  trips.push(created);
  summaryByTrip[created.id] = buildFallbackSummary(created);
  persistTrips();
  return deepClone(created);
}

function updateTrip(id, payload) {
  const index = trips.findIndex((item) => item.id === id);
  if (index < 0) {
    return null;
  }

  const current = trips[index];
  const updated = {
    ...current,
    ownerUserId:
      payload.ownerUserId !== undefined
        ? String(payload.ownerUserId)
        : current.ownerUserId ?? null,
    destinationName:
      payload.destinationName !== undefined
        ? String(payload.destinationName).trim()
        : current.destinationName,
    destinationCountry:
      payload.destinationCountry !== undefined
        ? String(payload.destinationCountry).trim()
        : current.destinationCountry,
    latitude: payload.latitude !== undefined ? Number(payload.latitude) : current.latitude,
    longitude: payload.longitude !== undefined ? Number(payload.longitude) : current.longitude,
    startDate: payload.startDate !== undefined ? String(payload.startDate) : current.startDate,
    endDate: payload.endDate !== undefined ? String(payload.endDate) : current.endDate,
    preferences:
      payload.preferences !== undefined
        ? Array.isArray(payload.preferences)
          ? payload.preferences.map((value) => String(value))
          : []
        : current.preferences,
    travelNotes:
      payload.travelNotes !== undefined
        ? String(payload.travelNotes)
        : current.travelNotes,
  };

  trips[index] = updated;
  summaryByTrip[id] = buildFallbackSummary(updated);
  persistTrips();
  return deepClone(updated);
}

function deleteTrip(id) {
  const before = trips.length;
  trips = trips.filter((item) => item.id !== id);
  delete summaryByTrip[id];
  const deleted = trips.length < before;
  if (deleted) {
    persistTrips();
  }
  return deleted;
}

function getTripWeather(id) {
  const summary = getTripSummarySeed(id);
  return deepClone(summary.weather);
}

function getTripGooglePlaces(id) {
  const summary = getTripSummarySeed(id);
  return deepClone(summary.googlePlaces);
}

function getTripRecommendations(id) {
  const summary = getTripSummarySeed(id);
  return deepClone(summary.recommendations);
}

function getTripCountryInfo(id) {
  const summary = getTripSummarySeed(id);
  return deepClone(summary.countryInfo);
}

function getTripSummary(id) {
  const trip = getTripById(id);
  if (!trip) {
    return null;
  }

  const summary = getTripSummarySeed(id);
  return {
    trip,
    weather: deepClone(summary.weather),
    googlePlaces: deepClone(summary.googlePlaces),
    recommendations: deepClone(summary.recommendations),
    countryInfo: deepClone(summary.countryInfo),
  };
}

function getTripSummarySeed(id) {
  if (!summaryByTrip[id]) {
    const trip = getTripById(id);
    summaryByTrip[id] = buildFallbackSummary(trip);
  }
  return summaryByTrip[id];
}

function buildFallbackSummary(trip) {
  if (!trip) {
    return {
      weather: {
        temperature: null,
        condition: "Unavailable",
        humidity: null,
        windSpeed: null,
      },
      googlePlaces: [],
      recommendations: [],
      countryInfo: {
        country: "Unknown",
        capital: "Unknown",
        currency: "Unknown",
        languages: [],
        region: "Unknown",
        flag: "Unknown",
      },
    };
  }

  return {
    weather: {
      temperature: null,
      condition: "Unavailable",
      humidity: null,
      windSpeed: null,
    },
    googlePlaces: [],
    recommendations: [],
    countryInfo: {
      country: trip.destinationCountry,
      capital: "Unavailable",
      currency: "Unavailable",
      languages: [],
      region: "Unavailable",
      flag: "",
    },
  };
}

function getUserByEmail(email) {
  return users.find((user) => user.email.toLowerCase() === email.toLowerCase()) ?? null;
}

function getUserById(userId) {
  return users.find((user) => user.id === userId) ?? null;
}

function getUserByVerificationTokenHash(tokenHash) {
  return (
    users.find(
      (user) => user.emailVerificationTokenHash === String(tokenHash),
    ) ?? null
  );
}

function getUserByPasswordResetTokenHash(tokenHash) {
  return (
    users.find((user) => user.passwordResetTokenHash === String(tokenHash)) ??
    null
  );
}

function markUserEmailVerified(userId) {
  const user = users.find((item) => item.id === userId);
  if (!user) {
    return null;
  }
  const now = new Date().toISOString();
  user.emailVerified = true;
  user.emailVerifiedAt = now;
  user.emailVerificationTokenHash = null;
  user.emailVerificationExpiresAt = null;
  user.updatedAt = now;
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    emailVerified: user.emailVerified,
    emailVerifiedAt: user.emailVerifiedAt,
  };
}

function setUserEmailVerification(userId, verification) {
  const user = users.find((item) => item.id === userId);
  if (!user) {
    return null;
  }
  user.emailVerificationTokenHash = verification.tokenHash;
  user.emailVerificationExpiresAt = verification.expiresAt;
  user.updatedAt = new Date().toISOString();
  return user;
}

function setUserPasswordReset(userId, reset) {
  const user = users.find((item) => item.id === userId);
  if (!user) {
    return null;
  }
  user.passwordResetTokenHash = reset.tokenHash;
  user.passwordResetExpiresAt = reset.expiresAt;
  user.updatedAt = new Date().toISOString();
  return user;
}

function updateUserPassword(userId, hashedPassword) {
  const user = users.find((item) => item.id === userId);
  if (!user) {
    return null;
  }
  user.password = String(hashedPassword);
  user.passwordResetTokenHash = null;
  user.passwordResetExpiresAt = null;
  user.updatedAt = new Date().toISOString();
  return user;
}

function markUserAppTourCompleted(userId) {
  const user = users.find((item) => item.id === userId);
  if (!user) {
    return null;
  }
  user.firstLogin = false;
  user.updatedAt = new Date().toISOString();
  return user;
}

function createUser(payload) {
  const now = new Date().toISOString();
  const created = {
    id: `user_${String(users.length + 1).padStart(3, "0")}`,
    name: String(payload.name).trim(),
    email: String(payload.email).trim().toLowerCase(),
    password: String(payload.password),
    emailVerified: Boolean(payload.emailVerified),
    emailVerifiedAt: payload.emailVerifiedAt ?? null,
    emailVerificationProvider: payload.emailVerificationProvider ?? "email",
    firebaseLocalId: payload.firebaseLocalId ?? null,
    emailVerificationTokenHash: payload.emailVerificationTokenHash ?? null,
    emailVerificationExpiresAt: payload.emailVerificationExpiresAt ?? null,
    passwordResetTokenHash: payload.passwordResetTokenHash ?? null,
    passwordResetExpiresAt: payload.passwordResetExpiresAt ?? null,
    firstLogin:
      payload.firstLogin !== undefined ? Boolean(payload.firstLogin) : true,
    createdAt: now,
    updatedAt: now,
  };
  users.push(created);
  return {
    id: created.id,
    name: created.name,
    email: created.email,
  };
}

function deleteExpiredUnverifiedUsers(referenceDate = new Date()) {
  const referenceTime = referenceDate.getTime();
  const expiredUserIds = users
    .filter((user) => isExpiredUnverifiedUser(user, referenceTime))
    .map((user) => user.id);

  if (expiredUserIds.length === 0) {
    return 0;
  }

  const expiredUserIdSet = new Set(expiredUserIds);
  users = users.filter((user) => !expiredUserIdSet.has(user.id));
  const tripsBefore = trips.length;
  trips = trips.filter((trip) => !expiredUserIdSet.has(trip.ownerUserId));
  if (trips.length !== tripsBefore) {
    persistTrips();
  }
  return expiredUserIds.length;
}

function isExpiredUnverifiedUser(user, referenceTime) {
  if (user.emailVerified) {
    return false;
  }
  const expiresAt = Date.parse(user.emailVerificationExpiresAt ?? "");
  return Number.isFinite(expiresAt) && expiresAt <= referenceTime;
}

module.exports = {
  listTrips,
  getTripById,
  createTrip,
  updateTrip,
  deleteTrip,
  getTripWeather,
  getTripGooglePlaces,
  getTripRecommendations,
  getTripCountryInfo,
  getTripSummary,
  getUserByEmail,
  getUserById,
  getUserByVerificationTokenHash,
  getUserByPasswordResetTokenHash,
  markUserEmailVerified,
  setUserEmailVerification,
  setUserPasswordReset,
  updateUserPassword,
  markUserAppTourCompleted,
  createUser,
  deleteExpiredUnverifiedUsers,
};
