const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");

test("preserves concurrent current and forecast cache writes", async () => {
  const cacheDirectory = await fs.mkdtemp(
    path.join(os.tmpdir(), "smart-trip-weather-cache-"),
  );
  process.env.TRIP_WEATHER_CACHE_DIR = cacheDirectory;

  const modulePath = require.resolve(
    "../src/services/tripWeatherFileCache",
  );
  delete require.cache[modulePath];
  const cache = require(modulePath);
  const trip = {
    id: "trip_concurrent",
    latitude: 3.139,
    longitude: 101.6869,
    updatedAt: "2026-06-20T00:00:00.000Z",
  };

  try {
    await Promise.all([
      cache.setWeatherCacheEntry({
        trip,
        entryName: "current",
        cacheKey: "current-key",
        data: { temperature: 30 },
        ttlMs: 60_000,
        provider: "test",
      }),
      cache.setWeatherCacheEntry({
        trip,
        entryName: "forecast",
        cacheKey: "forecast-key",
        data: { daily: [] },
        ttlMs: 60_000,
        provider: "test",
      }),
    ]);

    assert.deepEqual(
      (
        await cache.getWeatherCacheEntry(
          trip,
          "current",
          "current-key",
        )
      ).data,
      { temperature: 30 },
    );
    assert.deepEqual(
      (
        await cache.getWeatherCacheEntry(
          trip,
          "forecast",
          "forecast-key",
        )
      ).data,
      { daily: [] },
    );
  } finally {
    await fs.rm(cacheDirectory, { recursive: true, force: true });
    delete process.env.TRIP_WEATHER_CACHE_DIR;
    delete require.cache[modulePath];
  }
});
