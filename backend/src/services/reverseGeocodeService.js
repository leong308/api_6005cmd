/**
 * Reverse geocoding service.
 *
 * This file calls OpenStreetMap Nominatim to convert map coordinates into a
 * country name/code. Add Trip and Edit Trip use it to auto-fill the destination
 * country after a user selects a map point.
 */
const { HttpError } = require("../lib/http");
const countryService = require("./countryService");

const NOMINATIM_URL = "https://nominatim.openstreetmap.org/reverse";
const USER_AGENT =
  process.env.NOMINATIM_USER_AGENT || "SmartTravelPlanner/1.0 (local-development)";
const MIN_REQUEST_INTERVAL_MS = 1100;

const cache = new Map();
let nextRequestAt = 0;

function cacheKey(latitude, longitude) {
  return `${latitude.toFixed(5)},${longitude.toFixed(5)}`;
}

async function waitForRateLimit() {
  const delay = nextRequestAt - Date.now();
  if (delay > 0) {
    await new Promise((resolve) => setTimeout(resolve, delay));
  }
  nextRequestAt = Date.now() + MIN_REQUEST_INTERVAL_MS;
}

async function reverseGeocode(latitude, longitude) {
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    throw new HttpError(400, "Latitude and longitude must be valid numbers.");
  }

  const key = cacheKey(latitude, longitude);
  if (cache.has(key)) {
    return cache.get(key);
  }

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
  const result = {
    country: englishCountry,
    countryCode,
    displayName: data.display_name ?? "",
    latitude,
    longitude,
  };

  cache.set(key, result);
  return result;
}

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

module.exports = {
  reverseGeocode,
};
