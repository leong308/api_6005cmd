/**
 * Reverse geocoding service.
 *
 * This file calls OpenStreetMap Nominatim to convert map coordinates into a
 * country name/code. Add Trip and Edit Trip use it to auto-fill the destination
 * country after a user selects a map point.
 */
const { HttpError } = require("../lib/http");
const countryService = require("./countryService");
const geoapifyService = require("./geoapifyService");

const NOMINATIM_URL = "https://nominatim.openstreetmap.org/reverse";
const USER_AGENT =
  process.env.NOMINATIM_USER_AGENT || "SmartTravelPlanner/1.0 (local-development)";
const MIN_REQUEST_INTERVAL_MS = 1100;
const NOMINATIM_TIMEOUT_MS = readPositiveNumber(
  process.env.NOMINATIM_TIMEOUT_MS,
  10000,
);
const CACHE_TTL_MS = readPositiveNumber(
  process.env.REVERSE_GEOCODE_CACHE_TTL_MS,
  24 * 60 * 60 * 1000,
);
const NEGATIVE_CACHE_TTL_MS = readPositiveNumber(
  process.env.REVERSE_GEOCODE_NEGATIVE_CACHE_TTL_MS,
  60 * 1000,
);

const cache = new Map();
let nextRequestAt = 0;

/**
 * Supports the cache key backend flow.
 */
function cacheKey(latitude, longitude) {
  return `${latitude.toFixed(5)},${longitude.toFixed(5)}`;
}

/**
 * Supports the wait for rate limit backend flow.
 */
async function waitForRateLimit() {
  const now = Date.now();
  const scheduledAt = Math.max(now, nextRequestAt);
  nextRequestAt = scheduledAt + MIN_REQUEST_INTERVAL_MS;
  const delay = scheduledAt - now;
  if (delay > 0) {
    await new Promise((resolve) => setTimeout(resolve, delay));
  }
}

/**
 * Supports the reverse geocode backend flow.
 */
async function reverseGeocode(latitude, longitude) {
  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
    throw new HttpError(
      400,
      "Latitude must be a valid number between -90 and 90.",
    );
  }
  if (!Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    throw new HttpError(
      400,
      "Longitude must be a valid number between -180 and 180.",
    );
  }

  const key = cacheKey(latitude, longitude);
  const cached = cache.get(key);
  if (cached && cached.expiresAt > Date.now()) {
    return cached.data;
  }
  if (cached) {
    cache.delete(key);
  }

  try {
    const geoapifyResult = await geoapifyService.fetchCountryByCoordinates(
      latitude,
      longitude,
    );
    const normalizedGeoapifyResult = normalizeResult({
      ...geoapifyResult,
      latitude,
      longitude,
    });
    if (
      normalizedGeoapifyResult.country.length > 0 ||
      normalizedGeoapifyResult.countryCode.length > 0
    ) {
      rememberResult(key, normalizedGeoapifyResult, CACHE_TTL_MS);
      return normalizedGeoapifyResult;
    }
    console.warn("Geoapify country lookup returned no country.");
  } catch (error) {
    console.warn(`Geoapify country lookup failed: ${error.message}`);
  }

  try {
    const nominatimResult = await reverseGeocodeWithNominatim(
      latitude,
      longitude,
    );
    rememberResult(key, nominatimResult, CACHE_TTL_MS);
    return nominatimResult;
  } catch (error) {
    console.warn(`Nominatim country lookup failed: ${error.message}`);
    const unavailableResult = {
      country: "",
      countryCode: "",
      displayName: "",
      latitude,
      longitude,
      source: "unavailable",
      warning: "Country lookup is temporarily unavailable.",
    };
    rememberResult(key, unavailableResult, NEGATIVE_CACHE_TTL_MS);
    return unavailableResult;
  }
}

/**
 * Supports the reverse geocode with nominatim backend flow.
 */
async function reverseGeocodeWithNominatim(latitude, longitude) {
  await waitForRateLimit();

  const url = new URL(NOMINATIM_URL);
  url.searchParams.set("format", "jsonv2");
  url.searchParams.set("lat", latitude);
  url.searchParams.set("lon", longitude);
  url.searchParams.set("addressdetails", "1");
  url.searchParams.set("zoom", "5");
  url.searchParams.set("accept-language", "en");

  const response = await fetch(url, {
    headers: {
      "Accept-Language": "en",
      "User-Agent": USER_AGENT,
      Referer: "http://localhost:3000",
    },
    signal: AbortSignal.timeout(NOMINATIM_TIMEOUT_MS),
  });

  if (!response.ok) {
    throw new HttpError(
      response.status,
      `Reverse geocoding failed with status ${response.status}.`,
    );
  }

  const data = await response.json();
  const address = data.address ?? {};
  const countryCode = address.country_code
    ? String(address.country_code).toUpperCase()
    : "";
  const englishCountry = await englishCountryName(countryCode, address.country);
  return normalizeResult({
    country: englishCountry,
    countryCode,
    displayName: data.display_name ?? "",
    latitude,
    longitude,
    source: "nominatim",
  });
}

function rememberResult(key, data, ttlMs) {
  cache.set(key, {
    data,
    expiresAt: Date.now() + ttlMs,
  });
}

function readPositiveNumber(value, fallback) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

/**
 * Supports the english country name backend flow.
 */
async function englishCountryName(countryCode, fallback) {
  if (!countryCode) {
    return fallback ?? "";
  }

  try {
    return await countryService.fetchCountryNameByCode(countryCode);
  } catch (error) {
    console.warn(
      `Could not normalize country code ${countryCode} to English: ${error.message}`,
    );
    return fallback ?? "";
  }
}

/**
 * Normalizes the result value.
 */
function normalizeResult(result) {
  return {
    country: String(result.country ?? "").trim(),
    countryCode: String(result.countryCode ?? "").trim().toUpperCase(),
    displayName: String(result.displayName ?? "").trim(),
    latitude: Number(result.latitude),
    longitude: Number(result.longitude),
    source: String(result.source ?? "").trim() || "unknown",
    ...(result.warning ? { warning: String(result.warning) } : {}),
  };
}

module.exports = {
  reverseGeocode,
};
