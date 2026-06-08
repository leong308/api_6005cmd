/**
 * Trip-aware weather service.
 *
 * Wraps fallback weather provider calls with one-file-per-trip caching so
 * repeated trip screens, summaries, and agenda generation do not repeatedly
 * call providers.
 */
const weatherFileCache = require("./tripWeatherFileCache");
const weatherService = require("./weatherService");

const CURRENT_WEATHER_TTL_MS = readTtlMs(
  "TRIP_CURRENT_WEATHER_CACHE_TTL_MS",
  30 * 60 * 1000,
);
const DAILY_FORECAST_TTL_MS = readTtlMs(
  "TRIP_DAILY_FORECAST_CACHE_TTL_MS",
  6 * 60 * 60 * 1000,
);

async function fetchCurrentWeatherForTrip(trip) {
  const cacheKey = buildWeatherCacheKey(trip, "current");
  const cached = await weatherFileCache.getWeatherCacheEntry(
    trip,
    "current",
    cacheKey,
  );
  if (cached) {
    return {
      data: cached.data,
      provider: cached.provider ?? cached.data?.provider ?? "weather-cache",
      cached: true,
      stale: false,
    };
  }

  try {
    const data = await weatherService.fetchCurrentWeather(
      Number(trip.latitude),
      Number(trip.longitude),
    );
    await weatherFileCache.setWeatherCacheEntry({
      trip,
      entryName: "current",
      cacheKey,
      data,
      ttlMs: CURRENT_WEATHER_TTL_MS,
      provider: data.provider ?? "weather-fallback-chain",
    });
    return {
      data,
      provider: data.provider ?? "weather-fallback-chain",
      cached: false,
      stale: false,
    };
  } catch (error) {
    const stale = await weatherFileCache.getStaleWeatherCacheEntry(
      trip,
      "current",
      cacheKey,
    );
    if (stale) {
      return {
        data: stale.data,
        provider: stale.provider ?? stale.data?.provider ?? "weather-cache",
        cached: true,
        stale: true,
        warning: `Provider failed; serving stale cached weather. ${error.message}`,
      };
    }
    throw error;
  }
}

async function fetchDailyForecastForTrip(trip) {
  const cacheKey = buildWeatherCacheKey(trip, "forecast");
  const cached = await weatherFileCache.getWeatherCacheEntry(
    trip,
    "forecast",
    cacheKey,
  );
  if (cached) {
    return {
      data: cached.data,
      provider: cached.provider ?? cached.data?.provider ?? "weather-cache",
      cached: true,
      stale: false,
    };
  }

  try {
    const data = await weatherService.fetchDailyForecast(
      Number(trip.latitude),
      Number(trip.longitude),
      trip.startDate,
      trip.endDate,
    );
    await weatherFileCache.setWeatherCacheEntry({
      trip,
      entryName: "forecast",
      cacheKey,
      data,
      ttlMs: DAILY_FORECAST_TTL_MS,
      provider: data.provider ?? "weather-fallback-chain",
    });
    return {
      data,
      provider: data.provider ?? "weather-fallback-chain",
      cached: false,
      stale: false,
    };
  } catch (error) {
    const stale = await weatherFileCache.getStaleWeatherCacheEntry(
      trip,
      "forecast",
      cacheKey,
    );
    if (stale) {
      return {
        data: stale.data,
        provider: stale.provider ?? stale.data?.provider ?? "weather-cache",
        cached: true,
        stale: true,
        warning: `Provider failed; serving stale cached forecast. ${error.message}`,
      };
    }
    throw error;
  }
}

function buildWeatherCacheKey(trip, entryName) {
  return [
    entryName,
    trip.updatedAt ?? "",
    Number(trip.latitude).toFixed(4),
    Number(trip.longitude).toFixed(4),
    trip.startDate ?? "",
    trip.endDate ?? "",
  ].join(":");
}

function readTtlMs(key, fallback) {
  const value = Number(process.env[key]);
  if (!Number.isFinite(value) || value <= 0) {
    return fallback;
  }
  return value;
}

module.exports = {
  fetchCurrentWeatherForTrip,
  fetchDailyForecastForTrip,
};
