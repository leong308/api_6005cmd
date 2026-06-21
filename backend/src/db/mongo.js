/**
 * MongoDB connection helper.
 *
 * Uses MONGO_URI from backend/.env and keeps one shared MongoClient for the
 * backend process. Collections are indexed once after the first connection.
 */
const { MongoClient } = require("mongodb");

const DEFAULT_DB_NAME = "smart_travel_planner";
const SERVER_SELECTION_TIMEOUT_MS = Number(
  process.env.MONGO_SERVER_SELECTION_TIMEOUT_MS || 8000,
);

let clientPromise = null;
let dbPromise = null;
let indexesPromise = null;

/**
 * Checks whether mongo configured is true.
 */
function isMongoConfigured() {
  return readMongoUri().length > 0;
}

/**
 * Gets the db data.
 */
async function getDb() {
  if (!isMongoConfigured()) {
    throw new Error("MONGO_URI is not configured.");
  }

  if (!dbPromise) {
    dbPromise = connect().catch((error) => {
      dbPromise = null;
      indexesPromise = null;
      throw error;
    });
  }

  return dbPromise;
}

/**
 * Connects to the configured backend data store.
 */
async function connect() {
  const client = await getClient();
  const db = client.db(readMongoDbName());
  await ensureIndexes(db);
  return db;
}

/**
 * Gets the client data.
 */
async function getClient() {
  if (!clientPromise) {
    clientPromise = new MongoClient(readMongoUri(), {
      serverSelectionTimeoutMS: SERVER_SELECTION_TIMEOUT_MS,
    })
      .connect()
      .catch((error) => {
        clientPromise = null;
        dbPromise = null;
        indexesPromise = null;
        throw error;
      });
  }

  return clientPromise;
}

/**
 * Ensures the indexes input is valid.
 */
async function ensureIndexes(db) {
  if (!indexesPromise) {
    indexesPromise = Promise.all([
      db.collection("trips").createIndex({ id: 1 }, { unique: true }),
      db.collection("trips").createIndex({ ownerUserId: 1, id: 1 }),
      db.collection("users").createIndex({ id: 1 }, { unique: true }),
      db.collection("users").createIndex({ email: 1 }, { unique: true }),
      db.collection("users").createIndex({ emailVerificationTokenHash: 1 }),
      db.collection("users").createIndex({ passwordResetTokenHash: 1 }),
      db
        .collection("api_cache")
        .createIndex({ namespace: 1, key: 1 }, { unique: true }),
      db
        .collection("api_cache")
        .createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0 }),
    ]);
  }

  await indexesPromise;
}

/**
 * Reads the mongo uri value from configuration or input.
 */
function readMongoUri() {
  return String(process.env.MONGO_URI ?? "").trim();
}

/**
 * Reads the mongo db name value from configuration or input.
 */
function readMongoDbName() {
  const configuredName = String(process.env.MONGO_DB_NAME ?? "").trim();
  if (configuredName.length > 0) {
    return configuredName;
  }

  try {
    const uri = new URL(readMongoUri());
    const dbName = uri.pathname.replace(/^\//, "").trim();
    return dbName.length > 0 ? dbName : DEFAULT_DB_NAME;
  } catch (_error) {
    return DEFAULT_DB_NAME;
  }
}

/**
 * Closes the mongo resource.
 */
async function closeMongo() {
  if (!clientPromise) {
    return;
  }

  const client = await clientPromise;
  await client.close();
  clientPromise = null;
  dbPromise = null;
  indexesPromise = null;
}

module.exports = {
  closeMongo,
  getDb,
  isMongoConfigured,
};
