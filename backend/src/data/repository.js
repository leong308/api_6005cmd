/**
 * Application repository.
 *
 * MongoDB is the primary store when MONGO_URI is configured. The legacy JSON
 * store remains only as a local fallback for development without MongoDB.
 */
const localStore = require("./store");
const cacheRepository = require("./cacheRepository");
const { getDb, isMongoConfigured } = require("../db/mongo");

const TRIPS_COLLECTION = "trips";
const USERS_COLLECTION = "users";

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

async function createTrip(payload, ownerUserId = null) {
  if (!isMongoConfigured()) {
    return localStore.createTrip({ ...payload, ownerUserId });
  }

  const collection = await tripsCollection();
  const now = new Date().toISOString();
  const created = {
    ...normalizeTripPayload(payload),
    id: await generateTripId(collection),
    ownerUserId: ownerUserId ? String(ownerUserId) : null,
    createdAt: now,
    updatedAt: now,
  };

  await collection.insertOne(created);
  return toPublicTrip(created);
}

async function updateTrip(id, payload, ownerUserId = null) {
  if (!isMongoConfigured()) {
    const current = localStore.getTripById(id);
    if (!current || (ownerUserId && current.ownerUserId !== ownerUserId)) {
      return null;
    }
    return localStore.updateTrip(id, {
      ...payload,
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

async function getTripGooglePlaces(_id) {
  return [];
}

async function getTripWeather(id) {
  return localStore.getTripWeather(id);
}

async function getTripRecommendations(id) {
  return localStore.getTripRecommendations(id);
}

async function getTripCountryInfo(id) {
  return localStore.getTripCountryInfo(id);
}

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

async function getUserByEmail(email) {
  if (!isMongoConfigured()) {
    return localStore.getUserByEmail(email);
  }

  const user = await (await usersCollection()).findOne({
    email: normalizeEmail(email),
  });
  return user ? toUser(user, { includePassword: true }) : null;
}

async function getUserById(userId) {
  if (!isMongoConfigured()) {
    return localStore.getUserById(userId);
  }

  const user = await (await usersCollection()).findOne({ id: String(userId) });
  return user ? toUser(user, { includePassword: true }) : null;
}

async function createUser(payload) {
  if (!isMongoConfigured()) {
    return localStore.createUser(payload);
  }

  const collection = await usersCollection();
  const now = new Date().toISOString();
  const created = {
    id: await generateUserId(collection),
    name: String(payload.name).trim(),
    email: normalizeEmail(payload.email),
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

  await collection.insertOne(created);
  return toUser(created);
}

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

async function tripsCollection() {
  return (await getDb()).collection(TRIPS_COLLECTION);
}

async function usersCollection() {
  return (await getDb()).collection(USERS_COLLECTION);
}

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

function normalizeTripPayload(payload, current = {}) {
  return {
    destinationName:
      payload.destinationName !== undefined
        ? String(payload.destinationName).trim()
        : current.destinationName,
    destinationCountry:
      payload.destinationCountry !== undefined
        ? String(payload.destinationCountry).trim()
        : current.destinationCountry,
    latitude:
      payload.latitude !== undefined ? Number(payload.latitude) : current.latitude,
    longitude:
      payload.longitude !== undefined
        ? Number(payload.longitude)
        : current.longitude,
    startDate:
      payload.startDate !== undefined ? String(payload.startDate) : current.startDate,
    endDate:
      payload.endDate !== undefined ? String(payload.endDate) : current.endDate,
    preferences:
      payload.preferences !== undefined
        ? normalizePreferenceList(payload.preferences)
        : current.preferences ?? [],
    travelNotes:
      payload.travelNotes !== undefined
        ? String(payload.travelNotes)
        : current.travelNotes ?? "",
  };
}

function normalizePreferenceList(value) {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.map((item) => String(item));
}

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

function stripMongoId(value) {
  const { _id, ...publicValue } = value;
  return publicValue;
}

function normalizeEmail(email) {
  return String(email ?? "").trim().toLowerCase();
}

async function invalidateTripCaches(id) {
  await Promise.all([
    cacheRepository.deleteCachedValuesByPrefix("trip_summary", `${id}:`),
    cacheRepository.deleteCachedValuesByPrefix("trip_weather", `${id}:`),
    cacheRepository.deleteCachedValuesByPrefix("trip_forecast", `${id}:`),
    cacheRepository.deleteCachedValuesByPrefix("trip_recommendations", `${id}:`),
    cacheRepository.deleteCachedValuesByPrefix("trip_agenda", `${id}:`),
  ]);
}

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
