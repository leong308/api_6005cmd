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

async function getStaleWeatherCacheEntry(trip, entryName, cacheKey) {
  const file = await readTripCacheFile(trip.id);
  const entry = file.entries?.[entryName];
  if (!entry || entry.cacheKey !== cacheKey) {
    return null;
  }

  return {
    data: entry.data,
    provider: entry.provider,
    cachedAt: entry.cachedAt,
    expiresAt: entry.expiresAt,
  };
}

async function setWeatherCacheEntry({
  trip,
  entryName,
  cacheKey,
  data,
  ttlMs,
  provider,
}) {
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
}

async function deleteTripWeatherCache(tripId) {
  try {
    await fs.unlink(cachePath(tripId));
  } catch (error) {
    if (error.code !== "ENOENT") {
      throw error;
    }
  }
}

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

async function writeTripCacheFile(tripId, value) {
  await fs.mkdir(CACHE_DIR, { recursive: true });
  await fs.writeFile(cachePath(tripId), JSON.stringify(value, null, 2));
}

function cachePath(tripId) {
  return path.join(CACHE_DIR, `${safeFileName(tripId)}.json`);
}

function safeFileName(value) {
  return String(value).replace(/[^a-zA-Z0-9._-]/g, "_");
}

module.exports = {
  deleteTripWeatherCache,
  getStaleWeatherCacheEntry,
  getWeatherCacheEntry,
  setWeatherCacheEntry,
};
