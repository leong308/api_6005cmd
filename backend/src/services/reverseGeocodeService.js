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
  const delay = nextRequestAt - Date.now();
  if (delay > 0) {
    await new Promise((resolve) => setTimeout(resolve, delay));
  }
  nextRequestAt = Date.now() + MIN_REQUEST_INTERVAL_MS;
}

/**
 * Supports the reverse geocode backend flow.
 */
async function reverseGeocode(latitude, longitude) {
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    throw new HttpError(400, "Latitude and longitude must be valid numbers.");
  }

  const key = cacheKey(latitude, longitude);
  if (cache.has(key)) {
    return cache.get(key);
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
      cache.set(key, normalizedGeoapifyResult);
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
    cache.set(key, nominatimResult);
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
    cache.set(key, unavailableResult);
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
