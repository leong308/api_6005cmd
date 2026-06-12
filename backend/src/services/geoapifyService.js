/**
 * Geoapify Places fallback service.
 *
 * This file is used only when Foursquare recommendations are unavailable, for
 * example when the Foursquare quota is exhausted. It calls Geoapify Places API
 * with the trip coordinates and preference category, then maps Geoapify's
 * GeoJSON FeatureCollection response into the same recommendation model used by
 * the Flutter UI.
 */
const { HttpError } = require("../lib/http");
const cacheRepository = require("../data/cacheRepository");

const GEOAPIFY_PLACES_URL =
  process.env.GEOAPIFY_PLACES_URL || "https://api.geoapify.com/v2/places";
const GEOAPIFY_REVERSE_GEOCODING_URL =
  process.env.GEOAPIFY_REVERSE_GEOCODING_URL ||
  "https://api.geoapify.com/v1/geocode/reverse";
const GEOAPIFY_RADIUS_METERS = Number(
  process.env.GEOAPIFY_RADIUS_METERS || 8000,
);
const GEOAPIFY_TIMEOUT_MS = Number(process.env.GEOAPIFY_TIMEOUT_MS || 12000);
const CACHE_TTL_MS = 10 * 60 * 1000;
const DEFAULT_LIMIT = 5;
const COUNTRY_CACHE_NAMESPACE = "geoapify_reverse_country";
const COUNTRY_CACHE_PRECISION = readCountryCachePrecision();

const cache = new Map();
const countryCache = new Map();

/**
 * Fetches the country by coordinates data.
 */
async function fetchCountryByCoordinates(latitude, longitude) {
  validateCoordinates(latitude, longitude);

  const key = countryCacheKey(latitude, longitude);
  if (countryCache.has(key)) {
    return countryCache.get(key);
  }

  const persistentCached = await cacheRepository.getCachedValue(
    COUNTRY_CACHE_NAMESPACE,
    key,
  );
  if (persistentCached !== undefined) {
    countryCache.set(key, persistentCached);
    return persistentCached;
  }

  const url = buildReverseGeocodeUrl({ latitude, longitude });
  const response = await fetch(url, {
    signal: AbortSignal.timeout(GEOAPIFY_TIMEOUT_MS),
  });
  const body = await response.json().catch(() => ({}));

  if (!response.ok) {
    throw new HttpError(
      response.status || 502,
      extractGeoapifyError(body, response.status),
    );
  }

  const data = mapReverseGeocodeCountry(body, { latitude, longitude });
  countryCache.set(key, data);
  await cacheRepository.setCachedValue(COUNTRY_CACHE_NAMESPACE, key, data, {
    metadata: {
      provider: "geoapify-reverse-geocoding",
      precision: COUNTRY_CACHE_PRECISION,
    },
  });

  return data;
}

/**
 * Fetches backup recommendations for one preference near the trip coordinates.
 * This function preserves the same output shape as `foursquareService`, so
 * routes and summary aggregation do not need different UI handling.
 */
async function fetchGeoapifyRecommendations({
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
  const cached = cache.get(key);
  if (!forceRefresh && cached && cached.expiresAt > Date.now()) {
    return cached.data;
  }

  const url = buildPlacesUrl({
    latitude,
    longitude,
    preference: normalizedPreference,
    limit: normalizedLimit,
  });
  const response = await fetch(url, {
    signal: AbortSignal.timeout(GEOAPIFY_TIMEOUT_MS),
  });
  const body = await response.json().catch(() => ({}));

  if (!response.ok) {
    throw new HttpError(
      response.status || 502,
      extractGeoapifyError(body, response.status),
    );
  }

  const features = Array.isArray(body.features) ? body.features : [];
  const data = features
    .map((feature) =>
      mapFeatureToRecommendation(feature, {
        preference: normalizedPreference,
        openAt,
      }),
    )
    .filter(Boolean)
    .slice(0, normalizedLimit);

  cache.set(key, {
    data,
    expiresAt: Date.now() + CACHE_TTL_MS,
  });

  return data;
}

/**
 * Fetches Geoapify backup recommendation groups for multiple preferences.
 * Grouping mirrors Foursquare grouping: one result group per selected
 * preference chip.
 */
async function fetchGeoapifyRecommendationGroups({
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
        recommendations: await fetchGeoapifyRecommendations({
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
 * Builds the Geoapify Places URL.
 * Geoapify expects longitude before latitude inside `filter` and `bias`.
 */
function buildPlacesUrl({ latitude, longitude, preference, limit }) {
  const url = new URL(GEOAPIFY_PLACES_URL);
  url.searchParams.set("categories", categoriesForPreference(preference));
  url.searchParams.set(
    "filter",
    `circle:${longitude},${latitude},${GEOAPIFY_RADIUS_METERS}`,
  );
  url.searchParams.set("bias", `proximity:${longitude},${latitude}`);
  url.searchParams.set("limit", limit);
  url.searchParams.set("apiKey", readApiKey());
  return url;
}

/**
 * Builds the reverse geocode url payload.
 */
function buildReverseGeocodeUrl({ latitude, longitude }) {
  const url = new URL(GEOAPIFY_REVERSE_GEOCODING_URL);
  url.searchParams.set("lat", latitude);
  url.searchParams.set("lon", longitude);
  url.searchParams.set("type", "country");
  url.searchParams.set("format", "json");
  url.searchParams.set("lang", "en");
  url.searchParams.set("apiKey", readApiKey());
  return url;
}

/**
 * Maps the reverse geocode country data into the API shape.
 */
function mapReverseGeocodeCountry(body, { latitude, longitude }) {
  const result = firstReverseGeocodeResult(body);
  const country = String(
    result.country ??
      result.country_name ??
      result.name ??
      result.address?.country ??
      "",
  ).trim();
  const countryCode = String(
    result.country_code ??
      result.country_code_iso2 ??
      result.iso3166_1_alpha2 ??
      result.address?.country_code ??
      "",
  )
    .trim()
    .toUpperCase();

  return {
    country,
    countryCode,
    displayName: String(
      result.formatted ?? result.address_line1 ?? result.address_line2 ?? country,
    ),
    latitude,
    longitude,
    source: "geoapify-reverse-geocoding",
  };
}

/**
 * Supports the first reverse geocode result backend flow.
 */
function firstReverseGeocodeResult(body) {
  if (Array.isArray(body.results) && body.results.length > 0) {
    return body.results[0] ?? {};
  }
  if (Array.isArray(body.features) && body.features.length > 0) {
    return body.features[0]?.properties ?? {};
  }
  return {};
}

/**
 * Maps the feature to recommendation data into the API shape.
 */
function mapFeatureToRecommendation(feature, { preference, openAt }) {
  const properties = feature.properties ?? {};
  const coordinates = featureCoordinates(feature);
  if (!coordinates) {
    return null;
  }

  return {
    id: properties.place_id || properties.datasource?.raw?.osm_id || "",
    name: properties.name || `${titleForPreference(preference)} option`,
    category: categoryFromProperties(properties, preference),
    distanceMeters: Number.isFinite(properties.distance)
      ? properties.distance
      : 0,
    address:
      properties.formatted ||
      properties.address_line2 ||
      properties.address_line1 ||
      "",
    coordinates,
    link: "",
    website:
      properties.website ||
      properties.datasource?.raw?.website ||
      properties.datasource?.raw?.["contact:website"] ||
      "",
    source: "geoapify-places-fallback",
    hours: properties.opening_hours
      ? { display: properties.opening_hours }
      : null,
    popularHours: null,
    availability: {
      openAt: normalizeOpenAt(openAt),
      verifiedForVisitTime: false,
      source: "geoapify-places-fallback",
      label:
        "Fallback data from Geoapify Places; verify opening hours before visiting.",
    },
  };
}

/**
 * Gets latitude/longitude from GeoJSON geometry.
 * GeoJSON stores coordinates as `[longitude, latitude]`.
 */
function featureCoordinates(feature) {
  const coordinates = feature.geometry?.coordinates;
  if (!Array.isArray(coordinates) || coordinates.length < 2) {
    return null;
  }
  const longitude = Number(coordinates[0]);
  const latitude = Number(coordinates[1]);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return null;
  }
  return { latitude, longitude };
}

/**
 * Supports the categories for preference backend flow.
 */
function categoriesForPreference(preference) {
  const categories = {
    adventure: "tourism.attraction,leisure.park",
    arts: "tourism.attraction,entertainment",
    culture: "tourism.attraction,heritage",
    family: "tourism.attraction,leisure.park",
    food: "catering.restaurant,catering.cafe,catering.fast_food",
    history: "heritage,tourism.attraction",
    nightlife: "catering.bar,entertainment",
    nature: "leisure.park,leisure.park.garden,natural",
    outdoors: "leisure.park,tourism.attraction,natural",
    shopping: "commercial.supermarket,commercial.shopping_mall",
    wellness: "leisure.spa,leisure.park",
  };
  return categories[preference] ?? "tourism.attraction";
}

/**
 * Chooses the clearest category text from Geoapify properties.
 */
function categoryFromProperties(properties, fallback) {
  const categories = Array.isArray(properties.categories)
    ? properties.categories
    : [];
  return categories[0] || fallback;
}

/**
 * Reads the Geoapify API key from environment variables.
 * Keep the key in `backend/.env`; do not hardcode it in source files.
 */
function readApiKey() {
  const apiKey = String(process.env.GEOAPIFY_API_KEY ?? "").trim();
  if (!apiKey || apiKey.startsWith("your_")) {
    throw new HttpError(
      503,
      "GEOAPIFY_API_KEY is not configured.",
    );
  }
  return apiKey;
}

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
 * Supports the country cache key backend flow.
 */
function countryCacheKey(latitude, longitude) {
  return [
    Number(latitude).toFixed(COUNTRY_CACHE_PRECISION),
    Number(longitude).toFixed(COUNTRY_CACHE_PRECISION),
    "country",
  ].join(",");
}

/**
 * Reads the country cache precision value from configuration or input.
 */
function readCountryCachePrecision() {
  const precision = Number(process.env.GEOAPIFY_COUNTRY_CACHE_PRECISION || 3);
  if (!Number.isInteger(precision)) {
    return 3;
  }
  return Math.min(Math.max(precision, 2), 5);
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
 * Normalizes the preference value.
 */
function normalizePreference(value) {
  const text = String(value ?? "").trim().toLowerCase();
  return text.length === 0 ? "family" : text;
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
 * Applies per-preference limits when the UI requests different group sizes.
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
 * Keeps result counts in the same safe range used by Foursquare.
 */
function clampLimit(value) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed)) {
    return DEFAULT_LIMIT;
  }
  return Math.min(Math.max(parsed, 1), 10);
}

/**
 * Keeps open-at strings in Foursquare's supported `dayThhmm` format.
 * Geoapify does not filter by this value here, but the field is preserved in
 * the returned model so the agenda UI can still explain availability.
 */
function normalizeOpenAt(value) {
  const text = String(value ?? "").trim().toUpperCase();
  return /^[1-7]T[0-2][0-9][0-5][0-9]$/.test(text) ? text : "";
}

/**
 * Gives generated fallback labels a readable preference name.
 */
function titleForPreference(preference) {
  const labels = {
    adventure: "Adventure",
    arts: "Arts",
    culture: "Culture",
    family: "Family",
    food: "Food",
    history: "History",
    nightlife: "Nightlife",
    nature: "Nature",
    outdoors: "Outdoor",
    shopping: "Shopping",
    wellness: "Wellness",
  };
  return labels[preference] ?? "Local";
}

/**
 * Extracts the geoapify error value from a provider response.
 */
function extractGeoapifyError(body, status) {
  if (typeof body.message === "string" && body.message.trim().length > 0) {
    return body.message;
  }
  if (typeof body.error === "string" && body.error.trim().length > 0) {
    return body.error;
  }
  return `Geoapify Places returned status ${status}.`;
}

module.exports = {
  fetchCountryByCoordinates,
  fetchGeoapifyRecommendations,
  fetchGeoapifyRecommendationGroups,
};
