/**
 * Application repository.
 *
 * MongoDB is the primary store when MONGO_URI is configured. The legacy JSON
 * store remains only as a local fallback for development without MongoDB.
 */
const localStore = require("./store");
const cacheRepository = require("./cacheRepository");
const { getDb, isMongoConfigured } = require("../db/mongo");
const { HttpError } = require("../lib/http");
const { normalizeTripPayload } = require("../lib/tripValidation");

const TRIPS_COLLECTION = "trips";
const USERS_COLLECTION = "users";
const ID_INSERT_ATTEMPTS = 4;

/**
 * Lists the trips data.
 */
async function listTrips(ownerUserId = null) {
  if (!isMongoConfigured()) {
    return localStore
      .listTrips()
      .filter((trip) => !ownerUserId || trip.ownerUserId === ownerUserId);
  }

  const trips = await (await tripsCollection())
    .find(ownerUserId ? { ownerUserId: String(ownerUserId) } : {})
    .sort({ id: 1 })
    .toArray();
  return trips.map(toPublicTrip);
}

/**
 * Gets the trip by id data.
 */
async function getTripById(id, ownerUserId = null) {
  if (!isMongoConfigured()) {
    const trip = localStore.getTripById(id);
    if (!trip || (ownerUserId && trip.ownerUserId !== ownerUserId)) {
      return null;
    }
    return trip;
  }

  const query = { id: String(id) };
  if (ownerUserId) {
    query.ownerUserId = String(ownerUserId);
  }
  const trip = await (await tripsCollection()).findOne(query);
  return trip ? toPublicTrip(trip) : null;
}

/**
 * Creates the trip data.
 */
async function createTrip(payload, ownerUserId = null) {
  const normalizedPayload = normalizeTripPayload(payload);
  if (!isMongoConfigured()) {
    return localStore.createTrip({ ...normalizedPayload, ownerUserId });
  }

  const collection = await tripsCollection();
  const now = new Date().toISOString();
  const created = await insertWithGeneratedId({
    collection,
    generateId: generateTripId,
    buildDocument: (id) => ({
      ...normalizedPayload,
      id,
      ownerUserId: ownerUserId ? String(ownerUserId) : null,
      createdAt: now,
      updatedAt: now,
    }),
  });
  return toPublicTrip(created);
}

/**
 * Updates the trip data.
 */
async function updateTrip(id, payload, ownerUserId = null) {
  if (!isMongoConfigured()) {
    const current = localStore.getTripById(id);
    if (!current || (ownerUserId && current.ownerUserId !== ownerUserId)) {
      return null;
    }
    const normalizedPayload = normalizeTripPayload(payload, current);
    return localStore.updateTrip(id, {
      ...normalizedPayload,
      ownerUserId:
        current.ownerUserId ?? (ownerUserId ? String(ownerUserId) : null),
    });
  }

  const current = await getTripById(id, ownerUserId);
  if (!current) {
    return null;
  }

  const updatedFields = {
    ...normalizeTripPayload(payload, current),
    updatedAt: new Date().toISOString(),
  };
  const result = await (await tripsCollection()).findOneAndUpdate(
    tripOwnerQuery(id, ownerUserId),
    { $set: updatedFields },
    { returnDocument: "after" },
  );
  const updated = result?.value ?? result;
  await invalidateTripCaches(id);
  return updated ? toPublicTrip(updated) : null;
}

/**
 * Deletes the trip data.
 */
async function deleteTrip(id, ownerUserId = null) {
  if (!isMongoConfigured()) {
    const current = localStore.getTripById(id);
    if (!current || (ownerUserId && current.ownerUserId !== ownerUserId)) {
      return false;
    }
    return localStore.deleteTrip(id);
  }

  const result = await (await tripsCollection()).deleteOne(
    tripOwnerQuery(id, ownerUserId),
  );
  if (result.deletedCount > 0) {
    await invalidateTripCaches(id);
    return true;
  }
  return false;
}

/**
 * Gets the trip google places data.
 */
async function getTripGooglePlaces(_id) {
  return [];
}

/**
 * Gets the trip weather data.
 */
async function getTripWeather(id) {
  return localStore.getTripWeather(id);
}

/**
 * Gets the trip recommendations data.
 */
async function getTripRecommendations(id) {
  return localStore.getTripRecommendations(id);
}

/**
 * Gets the trip country info data.
 */
async function getTripCountryInfo(id) {
  return localStore.getTripCountryInfo(id);
}

/**
 * Gets the trip summary data.
 */
async function getTripSummary(id, ownerUserId = null) {
  const trip = await getTripById(id, ownerUserId);
  if (!trip) {
    return null;
  }

  return {
    trip,
    weather: await getTripWeather(id),
    googlePlaces: await getTripGooglePlaces(id),
    recommendations: await getTripRecommendations(id),
    countryInfo: await getTripCountryInfo(id),
  };
}

/**
 * Gets the user by email data.
 */
async function getUserByEmail(email) {
  if (!isMongoConfigured()) {
    return localStore.getUserByEmail(email);
  }

  const user = await (await usersCollection()).findOne({
    email: normalizeEmail(email),
  });
  return user ? toUser(user, { includePassword: true }) : null;
}

/**
 * Gets the user by id data.
 */
async function getUserById(userId) {
  if (!isMongoConfigured()) {
    return localStore.getUserById(userId);
  }

  const user = await (await usersCollection()).findOne({ id: String(userId) });
  return user ? toUser(user, { includePassword: true }) : null;
}

/**
 * Creates the user data.
 */
async function createUser(payload) {
  if (!isMongoConfigured()) {
    return localStore.createUser(payload);
  }

  const collection = await usersCollection();
  const now = new Date().toISOString();
  let created;
  try {
    created = await insertWithGeneratedId({
      collection,
      generateId: generateUserId,
      buildDocument: (id) => ({
        id,
        name: String(payload.name).trim(),
        email: normalizeEmail(payload.email),
        password: String(payload.password),
        emailVerified: Boolean(payload.emailVerified),
        emailVerifiedAt: payload.emailVerifiedAt ?? null,
        emailVerificationProvider:
          payload.emailVerificationProvider ?? "email",
        firebaseLocalId: payload.firebaseLocalId ?? null,
        emailVerificationTokenHash:
          payload.emailVerificationTokenHash ?? null,
        emailVerificationExpiresAt:
          payload.emailVerificationExpiresAt ?? null,
        passwordResetTokenHash: payload.passwordResetTokenHash ?? null,
        passwordResetExpiresAt: payload.passwordResetExpiresAt ?? null,
        firstLogin:
          payload.firstLogin !== undefined
            ? Boolean(payload.firstLogin)
            : true,
        createdAt: now,
        updatedAt: now,
      }),
    });
  } catch (error) {
    if (isDuplicateKeyFor(error, "email")) {
      throw new HttpError(409, "Email already exists.");
    }
    throw error;
  }
  return toUser(created);
}

/**
 * Gets the user by verification token hash data.
 */
async function getUserByVerificationTokenHash(tokenHash) {
  if (!isMongoConfigured()) {
    const user = localStore.getUserByVerificationTokenHash(tokenHash);
    return user ? toUser(user, { includePassword: true, includeVerification: true }) : null;
  }

  const user = await (await usersCollection()).findOne({
    emailVerificationTokenHash: String(tokenHash),
  });
  return user ? toUser(user, { includePassword: true, includeVerification: true }) : null;
}

/**
 * Gets the user by password reset token hash data.
 */
async function getUserByPasswordResetTokenHash(tokenHash) {
  if (!isMongoConfigured()) {
    const user = localStore.getUserByPasswordResetTokenHash(tokenHash);
    return user ? toUser(user, { includePassword: true, includeReset: true }) : null;
  }

  const user = await (await usersCollection()).findOne({
    passwordResetTokenHash: String(tokenHash),
  });
  return user ? toUser(user, { includePassword: true, includeReset: true }) : null;
}

/**
 * Supports the mark user email verified backend flow.
 */
async function markUserEmailVerified(userId) {
  if (!isMongoConfigured()) {
    const user = localStore.markUserEmailVerified(userId);
    return user ? toUser(user) : null;
  }

  const now = new Date().toISOString();
  const result = await (await usersCollection()).findOneAndUpdate(
    { id: String(userId) },
    {
      $set: {
        emailVerified: true,
        emailVerifiedAt: now,
        updatedAt: now,
      },
      $unset: {
        emailVerificationTokenHash: "",
        emailVerificationExpiresAt: "",
      },
    },
    { returnDocument: "after" },
  );
  const user = result?.value ?? result;
  return user ? toUser(user) : null;
}

/**
 * Sets the user email verification data.
 */
async function setUserEmailVerification(userId, verification) {
  if (!isMongoConfigured()) {
    const user = localStore.setUserEmailVerification(userId, verification);
    return user
      ? toUser(user, { includePassword: true, includeVerification: true })
      : null;
  }

  const result = await (await usersCollection()).findOneAndUpdate(
    { id: String(userId) },
    {
      $set: {
        emailVerificationTokenHash: verification.tokenHash,
        emailVerificationExpiresAt: verification.expiresAt,
        updatedAt: new Date().toISOString(),
      },
    },
    { returnDocument: "after" },
  );
  const user = result?.value ?? result;
  return user
    ? toUser(user, { includePassword: true, includeVerification: true })
    : null;
}

/**
 * Sets the user password reset data.
 */
async function setUserPasswordReset(userId, reset) {
  if (!isMongoConfigured()) {
    const user = localStore.setUserPasswordReset(userId, reset);
    return user ? toUser(user, { includePassword: true, includeReset: true }) : null;
  }

  const result = await (await usersCollection()).findOneAndUpdate(
    { id: String(userId) },
    {
      $set: {
        passwordResetTokenHash: reset.tokenHash,
        passwordResetExpiresAt: reset.expiresAt,
        updatedAt: new Date().toISOString(),
      },
    },
    { returnDocument: "after" },
  );
  const user = result?.value ?? result;
  return user ? toUser(user, { includePassword: true, includeReset: true }) : null;
}

/**
 * Updates the user password data.
 */
async function updateUserPassword(userId, hashedPassword) {
  if (!isMongoConfigured()) {
    const user = localStore.updateUserPassword(userId, hashedPassword);
    return user ? toUser(user) : null;
  }

  const result = await (await usersCollection()).findOneAndUpdate(
    { id: String(userId) },
    {
      $set: {
        password: String(hashedPassword),
        updatedAt: new Date().toISOString(),
      },
      $unset: {
        passwordResetTokenHash: "",
        passwordResetExpiresAt: "",
      },
    },
    { returnDocument: "after" },
  );
  const user = result?.value ?? result;
  return user ? toUser(user) : null;
}

/**
 * Supports the mark user app tour completed backend flow.
 */
async function markUserAppTourCompleted(userId) {
  if (!isMongoConfigured()) {
    const user = localStore.markUserAppTourCompleted(userId);
    return user ? toUser(user) : null;
  }

  const result = await (await usersCollection()).findOneAndUpdate(
    { id: String(userId) },
    {
      $set: {
        firstLogin: false,
        updatedAt: new Date().toISOString(),
      },
    },
    { returnDocument: "after" },
  );
  const user = result?.value ?? result;
  return user ? toUser(user) : null;
}

/**
 * Deletes the expired unverified users data.
 */
async function deleteExpiredUnverifiedUsers(referenceDate = new Date()) {
  if (!isMongoConfigured()) {
    return localStore.deleteExpiredUnverifiedUsers(referenceDate);
  }

  const referenceIso = referenceDate.toISOString();
  const collection = await usersCollection();
  const expiredUsers = await collection
    .find(
      {
        emailVerified: { $ne: true },
        emailVerificationExpiresAt: { $lte: referenceIso },
      },
      { projection: { id: 1 } },
    )
    .toArray();
  const expiredUserIds = expiredUsers.map((user) => user.id).filter(Boolean);
  if (expiredUserIds.length === 0) {
    return 0;
  }

  const result = await collection.deleteMany({
    id: { $in: expiredUserIds },
    emailVerified: { $ne: true },
    emailVerificationExpiresAt: { $lte: referenceIso },
  });
  await (await tripsCollection()).deleteMany({
    ownerUserId: { $in: expiredUserIds },
  });
  return result.deletedCount ?? 0;
}

/**
 * Supports the trips collection backend flow.
 */
async function tripsCollection() {
  return (await getDb()).collection(TRIPS_COLLECTION);
}

/**
 * Supports the users collection backend flow.
 */
async function usersCollection() {
  return (await getDb()).collection(USERS_COLLECTION);
}

/**
 * Generates the trip id value.
 */
async function generateTripId(collection) {
  const trips = await collection
    .find({ id: /^trip_\d+$/ }, { projection: { id: 1 } })
    .toArray();
  const maxNumber = trips.reduce((max, trip) => {
    const value = Number(String(trip.id).replace("trip_", ""));
    return Number.isNaN(value) ? max : Math.max(max, value);
  }, 0);
  return `trip_${String(maxNumber + 1).padStart(3, "0")}`;
}

/**
 * Generates the user id value.
 */
async function generateUserId(collection) {
  const users = await collection
    .find({ id: /^user_\d+$/ }, { projection: { id: 1 } })
    .toArray();
  const maxNumber = users.reduce((max, user) => {
    const value = Number(String(user.id).replace("user_", ""));
    return Number.isNaN(value) ? max : Math.max(max, value);
  }, 0);
  return `user_${String(maxNumber + 1).padStart(3, "0")}`;
}

/**
 * Retries sequential public-ID generation when concurrent inserts collide.
 */
async function insertWithGeneratedId({
  collection,
  generateId,
  buildDocument,
}) {
  for (let attempt = 1; attempt <= ID_INSERT_ATTEMPTS; attempt += 1) {
    const document = buildDocument(await generateId(collection));
    try {
      await collection.insertOne(document);
      return document;
    } catch (error) {
      if (
        !isDuplicateKeyFor(error, "id") ||
        attempt === ID_INSERT_ATTEMPTS
      ) {
        throw error;
      }
    }
  }
  throw new Error("Could not allocate a unique public ID.");
}

function isDuplicateKeyFor(error, fieldName) {
  if (Number(error?.code) !== 11000) {
    return false;
  }
  if (error.keyPattern && Object.hasOwn(error.keyPattern, fieldName)) {
    return true;
  }
  return String(error.message ?? "").includes(`${fieldName}_1`);
}

/**
 * Supports the to public trip backend flow.
 */
function toPublicTrip(trip) {
  return stripMongoId({
    id: trip.id,
    ownerUserId: trip.ownerUserId,
    destinationName: trip.destinationName,
    destinationCountry: trip.destinationCountry,
    latitude: trip.latitude,
    longitude: trip.longitude,
    startDate: trip.startDate,
    endDate: trip.endDate,
    preferences: Array.isArray(trip.preferences) ? trip.preferences : [],
    travelNotes: trip.travelNotes ?? "",
    createdAt: trip.createdAt,
    updatedAt: trip.updatedAt,
  });
}

/**
 * Supports the to user backend flow.
 */
function toUser(
  user,
  {
    includePassword = false,
    includeVerification = false,
    includeReset = false,
  } = {},
) {
  const publicUser = {
    id: user.id,
    name: user.name,
    email: user.email,
    emailVerified: Boolean(user.emailVerified),
    emailVerifiedAt: user.emailVerifiedAt ?? null,
    firstLogin: user.firstLogin !== false,
  };
  if (includePassword) {
    publicUser.password = user.password;
    publicUser.emailVerificationProvider =
      user.emailVerificationProvider ?? "email";
    publicUser.firebaseLocalId = user.firebaseLocalId ?? null;
  }
  if (includeVerification) {
    publicUser.emailVerificationTokenHash =
      user.emailVerificationTokenHash ?? null;
    publicUser.emailVerificationExpiresAt =
      user.emailVerificationExpiresAt ?? null;
  }
  if (includeReset) {
    publicUser.passwordResetTokenHash = user.passwordResetTokenHash ?? null;
    publicUser.passwordResetExpiresAt = user.passwordResetExpiresAt ?? null;
  }
  return publicUser;
}

/**
 * Supports the strip mongo id backend flow.
 */
function stripMongoId(value) {
  const { _id, ...publicValue } = value;
  return publicValue;
}

/**
 * Normalizes the email value.
 */
function normalizeEmail(email) {
  return String(email ?? "").trim().toLowerCase();
}

/**
 * Supports the invalidate trip caches backend flow.
 */
async function invalidateTripCaches(id) {
  await Promise.all([
    cacheRepository.deleteCachedValuesByPrefix("trip_summary", `${id}:`),
    cacheRepository.deleteCachedValuesByPrefix("trip_weather", `${id}:`),
    cacheRepository.deleteCachedValuesByPrefix("trip_forecast", `${id}:`),
    cacheRepository.deleteCachedValuesByPrefix("trip_recommendations", `${id}:`),
    cacheRepository.deleteCachedValuesByPrefix("trip_agenda", `${id}:`),
  ]);
}

/**
 * Supports the trip owner query backend flow.
 */
function tripOwnerQuery(id, ownerUserId) {
  const query = { id: String(id) };
  if (ownerUserId) {
    query.ownerUserId = String(ownerUserId);
  }
  return query;
}

module.exports = {
  createTrip,
  createUser,
  deleteExpiredUnverifiedUsers,
  deleteTrip,
  getTripById,
  getTripCountryInfo,
  getTripGooglePlaces,
  getTripRecommendations,
  getTripSummary,
  getTripWeather,
  getUserByEmail,
  getUserById,
  getUserByPasswordResetTokenHash,
  getUserByVerificationTokenHash,
  listTrips,
  markUserAppTourCompleted,
  markUserEmailVerified,
  setUserPasswordReset,
  setUserEmailVerification,
  updateUserPassword,
  updateTrip,
};
