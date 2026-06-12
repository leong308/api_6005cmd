/**
 * Foursquare recommendation service.
 *
 * This file is the primary recommendation provider for nearby attractions,
 * food, shops, and other trip preference categories. If Foursquare fails because
 * of quota, missing API keys, timeouts, or empty results, it automatically uses
 * Geoapify Places so the backend keeps returning usable data.
 */
const geoapifyService = require("./geoapifyService");
const cacheRepository = require("../data/cacheRepository");
const { HttpError } = require("../lib/http");

const FOURSQUARE_SEARCH_URL =
  process.env.FOURSQUARE_PLACES_SEARCH_URL ||
  "https://places-api.foursquare.com/places/search";
const FOURSQUARE_PLACES_API_VERSION =
  process.env.FOURSQUARE_PLACES_API_VERSION || "2025-02-05";
const CACHE_TTL_MS = 10 * 60 * 1000;
const DEFAULT_RADIUS_METERS = 8000;
const DEFAULT_LIMIT = 5;
const FOURSQUARE_TIMEOUT_MS = Number(process.env.FOURSQUARE_TIMEOUT_MS || 10000);
const NEGATIVE_CACHE_TTL_MS = Number(
  process.env.RECOMMENDATION_EMPTY_CACHE_TTL_MS || 15 * 60 * 1000,
);

const cache = new Map();

/**
 * Supports the cache key backend flow.
 */
function cacheKey(latitude, longitude, preference, limit, openAt) {
  return [
    latitude.toFixed(4),
    longitude.toFixed(4),
    preference.toLowerCase(),
    limit,
    openAt || "anytime",
  ].join(",");
}

/**
 * Reads the api key value from configuration or input.
 */
function readApiKey() {
  const apiKey = process.env.FOURSQUARE_API_KEY;
  if (!apiKey || apiKey.trim().length === 0 || apiKey.startsWith("your_")) {
    throw new HttpError(
      503,
      "FOURSQUARE_API_KEY is not configured for live Foursquare recommendations.",
    );
  }
  return apiKey.trim();
}

/**
 * Validates the coordinates input.
 */
function validateCoordinates(latitude, longitude) {
  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
    throw new HttpError(400, "Latitude must be a valid number between -90 and 90.");
  }
  if (!Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    throw new HttpError(
      400,
      "Longitude must be a valid number between -180 and 180.",
    );
  }
}

/**
 * Fetches recommendations for one preference.
 * Foursquare is tried first; if it fails or returns no venues, the backup
 * service returns Geoapify Places fallback recommendations.
 */
async function fetchRecommendations({
  latitude,
  longitude,
  preference = "family",
  limit = DEFAULT_LIMIT,
  openAt = "",
  forceRefresh = false,
}) {
  validateCoordinates(latitude, longitude);

  const normalizedPreference = normalizePreference(preference);
  const normalizedLimit = clampLimit(limit);
  const key = cacheKey(
    latitude,
    longitude,
    normalizedPreference,
    normalizedLimit,
    normalizeOpenAt(openAt),
  );
  const mongoCached = await cacheRepository.getCachedValue(
    "recommendations",
    key,
  );
  if (!forceRefresh && mongoCached !== undefined) {
    cache.set(key, {
      data: mongoCached,
      expiresAt: Date.now() + CACHE_TTL_MS,
    });
    return mongoCached;
  }

  const cached = cache.get(key);
  if (!forceRefresh && cached && cached.expiresAt > Date.now()) {
    return cached.data;
  }

  try {
    const apiKey = readApiKey();
    let response = await requestFoursquare({
      apiKey,
      latitude,
      longitude,
      preference: normalizedPreference,
      limit: normalizedLimit,
      openAt: normalizeOpenAt(openAt),
      authMode: process.env.FOURSQUARE_AUTH_SCHEME?.toLowerCase(),
    });
    if (
      response.status === 401 &&
      !process.env.FOURSQUARE_AUTH_SCHEME
    ) {
      response = await requestFoursquare({
        apiKey,
        latitude,
        longitude,
        preference: normalizedPreference,
        limit: normalizedLimit,
        openAt: normalizeOpenAt(openAt),
        authMode: "raw",
      });
    }
    const body = await response.json().catch(() => ({}));

    if (!response.ok) {
      const message = extractErrorMessage(body, response.status);
      throw new HttpError(response.status, message);
    }

    const results = Array.isArray(body.results) ? body.results : [];
    const data = results.map((place) =>
      mapPlaceToRecommendation(place, { openAt: normalizeOpenAt(openAt) }),
    );

    if (data.length > 0) {
      await rememberRecommendations(key, data);
      return data;
    }

    console.error(
      `Foursquare returned no ${normalizedPreference} results; using fallback recommendations.`,
    );
  } catch (error) {
    console.error(
      `Foursquare failed for ${normalizedPreference}; using fallback recommendations: ${error.message}`,
    );
  }

  const data = await geoapifyService.fetchGeoapifyRecommendations({
    latitude,
    longitude,
    preference: normalizedPreference,
    limit: normalizedLimit,
    openAt: normalizeOpenAt(openAt),
    forceRefresh,
  }).catch((error) => {
    console.error(
      `Geoapify fallback failed for ${normalizedPreference}: ${error.message}`,
    );
    return [];
  });
  await rememberRecommendations(key, data);

  return data;
}

/**
 * Fetches the recommendation groups data.
 */
async function fetchRecommendationGroups({
  latitude,
  longitude,
  preferences = [],
  limit = DEFAULT_LIMIT,
  limitsByPreference = {},
  forceRefresh = false,
}) {
  const normalizedPreferences = normalizePreferences(preferences);
  const normalizedLimit = clampLimit(limit);

  return Promise.all(
    normalizedPreferences.map(async (preference) => {
      const groupLimit = limitForPreference(
        preference,
        limitsByPreference,
        normalizedLimit,
      );
      return {
        preference,
        limit: groupLimit,
        recommendations: await fetchRecommendations({
          latitude,
          longitude,
          preference,
          limit: groupLimit,
          forceRefresh,
        }),
      };
    }),
  );
}

/**
 * Performs the raw Foursquare Places Search HTTP request.
 */
async function requestFoursquare({
  apiKey,
  latitude,
  longitude,
  preference,
  limit,
  openAt,
  authMode,
}) {
  const url = new URL(FOURSQUARE_SEARCH_URL);
  url.searchParams.set("ll", `${latitude},${longitude}`);
  url.searchParams.set("query", queryForPreference(preference));
  url.searchParams.set("radius", DEFAULT_RADIUS_METERS);
  url.searchParams.set("limit", limit);
  url.searchParams.set("sort", "distance");
  if (openAt) {
    url.searchParams.set("open_at", openAt);
  }
  url.searchParams.set(
    "fields",
    [
      "fsq_place_id",
      "name",
      "categories",
      "distance",
      "latitude",
      "longitude",
      "location",
      "hours",
      "hours_popular",
      "link",
      "website",
    ].join(","),
  );

  return fetch(url, {
    headers: {
      Accept: "application/json",
      Authorization: authHeaderValue(apiKey, authMode),
      "X-places-api-version": FOURSQUARE_PLACES_API_VERSION,
    },
    signal: AbortSignal.timeout(FOURSQUARE_TIMEOUT_MS),
  });
}

/**
 * Supports the auth header value backend flow.
 */
function authHeaderValue(apiKey, authMode) {
  if (/^Bearer\s+/i.test(apiKey)) {
    return apiKey;
  }
  if (authMode === "raw") {
    return apiKey;
  }
  return `Bearer ${apiKey}`;
}

/**
 * Extracts the error message value from a provider response.
 */
function extractErrorMessage(body, status) {
  if (typeof body.message === "string" && body.message.trim().length > 0) {
    return body.message;
  }
  if (typeof body.error === "string" && body.error.trim().length > 0) {
    return body.error;
  }
  if (
    typeof body.error?.message === "string" &&
    body.error.message.trim().length > 0
  ) {
    return body.error.message;
  }
  return `Foursquare returned status ${status}.`;
}

/**
 * Maps the place to recommendation data into the API shape.
 */
function mapPlaceToRecommendation(place, { openAt = "" } = {}) {
  const category = Array.isArray(place.categories)
    ? place.categories[0]?.name ?? "recommendation"
    : "recommendation";
  const location = place.location ?? {};
  const geocodes = place.geocodes?.main ?? {};
  const latitude = place.latitude ?? geocodes.latitude ?? null;
  const longitude = place.longitude ?? geocodes.longitude ?? null;

  return {
    id: place.fsq_place_id ?? place.fsq_id ?? "",
    name: place.name ?? "Unnamed recommendation",
    category,
    distanceMeters: Number.isFinite(place.distance) ? place.distance : 0,
    address: addressLabel(location),
    coordinates: {
      latitude,
      longitude,
    },
    link: place.link ?? "",
    website: place.website ?? "",
    source: "foursquare",
    hours: place.hours ?? null,
    popularHours: place.hours_popular ?? null,
    availability: {
      openAt,
      verifiedForVisitTime: openAt.length > 0,
      source: openAt.length > 0
        ? "foursquare-open_at-filter"
        : "foursquare-search",
    },
  };
}

/**
 * Supports the address label backend flow.
 */
function addressLabel(location) {
  if (Array.isArray(location.formatted_address)) {
    return location.formatted_address.filter(Boolean).join(", ");
  }
  if (typeof location.formatted_address === "string") {
    return location.formatted_address;
  }

  return [
    location.address,
    location.locality,
    location.region,
    location.country,
  ]
    .filter(Boolean)
    .join(", ");
}

/**
 * Normalizes the preference value.
 */
function normalizePreference(value) {
  const text = String(value ?? "").trim().toLowerCase();
  return text.length === 0 ? "family" : text;
}

/**
 * Normalizes the open at value.
 */
function normalizeOpenAt(value) {
  const text = String(value ?? "").trim().toUpperCase();
  return /^[1-7]T[0-2][0-9][0-5][0-9]$/.test(text) ? text : "";
}

/**
 * Normalizes the preferences value.
 */
function normalizePreferences(values) {
  const source = Array.isArray(values) ? values : [values];
  const preferences = source
    .map(normalizePreference)
    .filter((preference) => preference.length > 0);
  const unique = [...new Set(preferences)];
  return unique.length === 0 ? ["family"] : unique;
}

/**
 * Chooses the limit for one preference group.
 */
function limitForPreference(preference, limitsByPreference, fallbackLimit) {
  const key = normalizePreference(preference);
  const limit =
    limitsByPreference?.[key] ??
    limitsByPreference?.[preference] ??
    fallbackLimit;
  return clampLimit(limit);
}

/**
 * Supports the query for preference backend flow.
 */
function queryForPreference(preference) {
  const queries = {
    adventure: "adventure attraction",
    arts: "art gallery museum",
    culture: "museum landmark culture",
    family: "family attraction",
    food: "restaurant local food",
    history: "historic landmark",
    nightlife: "nightlife bar",
    nature: "park nature",
    outdoors: "park outdoor attraction",
    shopping: "shopping mall market",
    wellness: "spa wellness",
  };
  return queries[preference] ?? preference;
}

/**
 * Keeps result limits within the supported range.
 */
function clampLimit(value) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed)) {
    return DEFAULT_LIMIT;
  }
  return Math.min(Math.max(parsed, 1), 10);
}

/**
 * Supports the remember recommendations backend flow.
 */
async function rememberRecommendations(key, data) {
  cache.set(key, {
    data,
    expiresAt: Date.now() + CACHE_TTL_MS,
  });

  await cacheRepository.setCachedValue("recommendations", key, data, {
    ttlMs: data.length > 0 ? undefined : NEGATIVE_CACHE_TTL_MS,
    metadata: {
      provider: data[0]?.source ?? "empty",
      resultCount: data.length,
    },
  });
}

module.exports = {
  fetchRecommendations,
  fetchRecommendationGroups,
};
