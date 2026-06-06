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

function isMongoConfigured() {
  return readMongoUri().length > 0;
}

async function getDb() {
  if (!isMongoConfigured()) {
    throw new Error("MONGO_URI is not configured.");
  }

  if (!dbPromise) {
    dbPromise = connect();
  }

  return dbPromise;
}

async function connect() {
  const client = await getClient();
  const db = client.db(readMongoDbName());
  await ensureIndexes(db);
  return db;
}

async function getClient() {
  if (!clientPromise) {
    clientPromise = new MongoClient(readMongoUri(), {
      serverSelectionTimeoutMS: SERVER_SELECTION_TIMEOUT_MS,
    }).connect();
  }

  return clientPromise;
}

async function ensureIndexes(db) {
  if (!indexesPromise) {
    indexesPromise = Promise.all([
      db.collection("trips").createIndex({ id: 1 }, { unique: true }),
      db.collection("trips").createIndex({ ownerUserId: 1, id: 1 }),
      db.collection("users").createIndex({ id: 1 }, { unique: true }),
      db.collection("users").createIndex({ email: 1 }, { unique: true }),
      db.collection("users").createIndex({ emailVerificationTokenHash: 1 }),
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

function readMongoUri() {
  return String(process.env.MONGO_URI ?? "").trim();
}

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
