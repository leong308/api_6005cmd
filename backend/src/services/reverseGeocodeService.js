const { HttpError } = require("../lib/http");

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

  const response = await fetch(url, {
    headers: {
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
  const result = {
    country: address.country ?? "",
    countryCode: address.country_code ? String(address.country_code).toUpperCase() : "",
    displayName: data.display_name ?? "",
    latitude,
    longitude,
  };

  cache.set(key, result);
  return result;
}

module.exports = {
  reverseGeocode,
};
