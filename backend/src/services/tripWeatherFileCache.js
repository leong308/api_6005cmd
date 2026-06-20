/**
 * Per-trip weather file cache.
 *
 * Each trip gets one JSON cache file under backend/.data/weather-cache. The
 * file stores current weather and forecast entries separately, keyed by the
 * trip coordinates/date window so edits naturally invalidate stale entries.
 */
const fs = require("fs/promises");
const path = require("path");

const CACHE_DIR =
  process.env.TRIP_WEATHER_CACHE_DIR ||
  path.join(__dirname, "..", "..", ".data", "weather-cache");
const tripWriteQueues = new Map();

/**
 * Gets the weather cache entry data.
 */
async function getWeatherCacheEntry(trip, entryName, cacheKey) {
  const file = await readTripCacheFile(trip.id);
  const entry = file.entries?.[entryName];
  if (!entry || entry.cacheKey !== cacheKey) {
    return null;
  }

  const expiresAt = Date.parse(entry.expiresAt ?? "");
  if (!Number.isFinite(expiresAt) || expiresAt <= Date.now()) {
    return null;
  }

  return {
    data: entry.data,
    provider: entry.provider,
    cachedAt: entry.cachedAt,
    expiresAt: entry.expiresAt,
  };
}

/**
 * Gets the stale weather cache entry data.
 */
async function getStaleWeatherCacheEntry(
  trip,
  entryName,
  cacheKey,
  { maxAgeMs } = {},
) {
  const file = await readTripCacheFile(trip.id);
  const entry = file.entries?.[entryName];
  if (!entry || entry.cacheKey !== cacheKey) {
    return null;
  }

  if (isOlderThan(entry.cachedAt, maxAgeMs)) {
    await deleteWeatherCacheEntry(trip.id, entryName, cacheKey);
    return null;
  }

  return {
    data: entry.data,
    provider: entry.provider,
    cachedAt: entry.cachedAt,
    expiresAt: entry.expiresAt,
  };
}

/**
 * Deletes the weather cache entry data.
 */
async function deleteWeatherCacheEntry(tripId, entryName, cacheKey) {
  await withTripWriteLock(tripId, async () => {
    const file = await readTripCacheFile(tripId);
    const entry = file.entries?.[entryName];
    if (!entry || entry.cacheKey !== cacheKey) {
      return;
    }

    const nextEntries = { ...(file.entries ?? {}) };
    delete nextEntries[entryName];

    if (Object.keys(nextEntries).length === 0) {
      await deleteTripWeatherCacheUnlocked(tripId);
      return;
    }

    await writeTripCacheFile(tripId, {
      ...file,
      updatedAt: new Date().toISOString(),
      entries: nextEntries,
    });
  });
}

/**
 * Sets the weather cache entry data.
 */
async function setWeatherCacheEntry({
  trip,
  entryName,
  cacheKey,
  data,
  ttlMs,
  provider,
}) {
  await withTripWriteLock(trip.id, async () => {
    const now = new Date();
    const file = await readTripCacheFile(trip.id);
    const nextFile = {
      tripId: String(trip.id),
      tripUpdatedAt: trip.updatedAt ?? null,
      coordinates: {
        latitude: Number(trip.latitude),
        longitude: Number(trip.longitude),
      },
      updatedAt: now.toISOString(),
      entries: {
        ...(file.entries ?? {}),
        [entryName]: {
          cacheKey,
          provider,
          cachedAt: now.toISOString(),
          expiresAt: new Date(now.getTime() + ttlMs).toISOString(),
          data,
        },
      },
    };

    await writeTripCacheFile(trip.id, nextFile);
  });
}

/**
 * Deletes the trip weather cache data.
 */
async function deleteTripWeatherCache(tripId) {
  await withTripWriteLock(tripId, () =>
    deleteTripWeatherCacheUnlocked(tripId),
  );
}

async function deleteTripWeatherCacheUnlocked(tripId) {
  try {
    await fs.unlink(cachePath(tripId));
  } catch (error) {
    if (error.code !== "ENOENT") {
      throw error;
    }
  }
}

/**
 * Reads the trip cache file value from configuration or input.
 */
async function readTripCacheFile(tripId) {
  try {
    const raw = await fs.readFile(cachePath(tripId), "utf8");
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch (error) {
    if (error.code === "ENOENT") {
      return {};
    }
    console.warn(`Could not read weather cache for ${tripId}: ${error.message}`);
    return {};
  }
}

/**
 * Supports the write trip cache file backend flow.
 */
async function writeTripCacheFile(tripId, value) {
  await fs.mkdir(CACHE_DIR, { recursive: true });
  const targetPath = cachePath(tripId);
  const temporaryPath = `${targetPath}.${process.pid}.${Date.now()}.tmp`;
  try {
    await fs.writeFile(temporaryPath, JSON.stringify(value, null, 2));
    await fs.rename(temporaryPath, targetPath);
  } catch (error) {
    await fs.unlink(temporaryPath).catch(() => {});
    throw error;
  }
}

async function withTripWriteLock(tripId, action) {
  const key = String(tripId);
  const previous = tripWriteQueues.get(key) ?? Promise.resolve();
  const operation = previous.catch(() => {}).then(action);
  tripWriteQueues.set(key, operation);

  try {
    return await operation;
  } finally {
    if (tripWriteQueues.get(key) === operation) {
      tripWriteQueues.delete(key);
    }
  }
}

/**
 * Supports the cache path backend flow.
 */
function cachePath(tripId) {
  return path.join(CACHE_DIR, `${safeFileName(tripId)}.json`);
}

/**
 * Supports the safe file name backend flow.
 */
function safeFileName(value) {
  return String(value).replace(/[^a-zA-Z0-9._-]/g, "_");
}

/**
 * Checks whether older than is true.
 */
function isOlderThan(cachedAt, maxAgeMs) {
  if (!Number.isFinite(maxAgeMs) || maxAgeMs <= 0) {
    return false;
  }

  const cachedAtMs = Date.parse(cachedAt ?? "");
  if (!Number.isFinite(cachedAtMs)) {
    return true;
  }

  return Date.now() - cachedAtMs > maxAgeMs;
}

module.exports = {
  deleteWeatherCacheEntry,
  deleteTripWeatherCache,
  getStaleWeatherCacheEntry,
  getWeatherCacheEntry,
  setWeatherCacheEntry,
};
