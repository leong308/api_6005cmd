/**
 * Mongo-backed API cache.
 *
 * Cache reads intentionally go to Mongo before provider calls. A missing
 * MONGO_URI disables persistent caching and lets services use their in-memory
 * caches/fallbacks.
 */
const { getDb, isMongoConfigured } = require("../db/mongo");

const COLLECTION = "api_cache";

async function getCachedValue(namespace, key) {
  if (!isMongoConfigured()) {
    return undefined;
  }

  const collection = await getCollection();
  const doc = await collection.findOne({ namespace, key });
  if (!doc) {
    return undefined;
  }

  if (doc.expiresAt && new Date(doc.expiresAt).getTime() <= Date.now()) {
    await collection.deleteOne({ namespace, key });
    return undefined;
  }

  return doc.value;
}

async function setCachedValue(namespace, key, value, options = {}) {
  if (!isMongoConfigured()) {
    return;
  }

  const now = new Date();
  const ttlMs = Number(options.ttlMs);
  const expiresAt = Number.isFinite(ttlMs) && ttlMs > 0
    ? new Date(now.getTime() + ttlMs)
    : null;

  const $set = {
    namespace,
    key,
    value,
    metadata: options.metadata ?? {},
    updatedAt: now,
  };

  if (expiresAt) {
    $set.expiresAt = expiresAt;
  }

  const update = {
    $set,
    $setOnInsert: { createdAt: now },
  };

  if (!expiresAt) {
    update.$unset = { expiresAt: "" };
  }

  await (await getCollection()).updateOne(
    { namespace, key },
    update,
    { upsert: true },
  );
}

async function deleteCachedValue(namespace, key) {
  if (!isMongoConfigured()) {
    return;
  }

  await (await getCollection()).deleteOne({ namespace, key });
}

async function deleteCachedValuesByPrefix(namespace, keyPrefix) {
  if (!isMongoConfigured()) {
    return;
  }

  await (await getCollection()).deleteMany({
    namespace,
    key: { $regex: `^${escapeRegExp(keyPrefix)}` },
  });
}

async function getCollection() {
  const db = await getDb();
  return db.collection(COLLECTION);
}

function escapeRegExp(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

module.exports = {
  deleteCachedValue,
  deleteCachedValuesByPrefix,
  getCachedValue,
  setCachedValue,
};
