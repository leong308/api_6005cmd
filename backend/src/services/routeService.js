/**
 * Google Routes service.
 *
 * This file calls Google Routes API for walking/driving paths, maps the provider
 * response into app-friendly route data, and decodes Google polylines into
 * latitude/longitude points for map rendering.
 */
const cacheRepository = require("../data/cacheRepository");
const { HttpError } = require("../lib/http");

const GOOGLE_ROUTES_URL =
  process.env.GOOGLE_ROUTES_API_URL ||
  "https://routes.googleapis.com/directions/v2:computeRoutes";
const GOOGLE_ROUTES_FIELD_MASK =
  "routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline";
const GOOGLE_ROUTES_TIMEOUT_MS = Number(
  process.env.GOOGLE_ROUTES_TIMEOUT_MS || 12000,
);
const ROUTE_MODES = {
  walk: {
    mode: "walk",
    label: "Walk",
    travelMode: "WALK",
    transitModes: [],
  },
  car: {
    mode: "car",
    label: "Vehicle",
    travelMode: "DRIVE",
    transitModes: [],
  },
};

/**
 * Fetches the route data.
 */
async function fetchRoute({
  fromLatitude,
  fromLongitude,
  toLatitude,
  toLongitude,
  mode = "walk",
}) {
  validateCoordinates(fromLatitude, fromLongitude, "Origin");
  validateCoordinates(toLatitude, toLongitude, "Destination");
  const routeMode = routeModeConfig(mode);
  const cacheKey = buildRouteCacheKey({
    fromLatitude,
    fromLongitude,
    toLatitude,
    toLongitude,
    mode: routeMode.mode,
  });
  const cachedRoute = await cacheRepository.getCachedValue("routes", cacheKey);
  if (cachedRoute !== undefined) {
    return cachedRoute;
  }

  const response = await fetch(GOOGLE_ROUTES_URL, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      "X-Goog-Api-Key": readApiKey(),
      "X-Goog-FieldMask": GOOGLE_ROUTES_FIELD_MASK,
    },
    signal: AbortSignal.timeout(GOOGLE_ROUTES_TIMEOUT_MS),
    body: JSON.stringify(
      buildRouteRequest({
        fromLatitude,
        fromLongitude,
        toLatitude,
        toLongitude,
        routeMode,
      }),
    ),
  });
  const body = await response.json().catch(() => ({}));

  if (!response.ok) {
    throw new HttpError(
      response.status || 502,
      extractRouteError(body, response.status),
    );
  }

  const route = Array.isArray(body.routes) ? body.routes[0] : null;
  const encodedPolyline = route?.polyline?.encodedPolyline;
  if (!route || typeof encodedPolyline !== "string" || !encodedPolyline) {
    throw new HttpError(502, "Google Routes API did not return a route.");
  }

  const distanceMeters = Number(route.distanceMeters) || 0;
  const durationSeconds = parseDurationSeconds(route.duration);
  const path = decodePolyline(encodedPolyline);
  if (path.length === 0) {
    throw new HttpError(502, "Google Routes API returned an empty route path.");
  }

  const data = {
    provider: "google-routes",
    mode: routeMode.mode,
    modeLabel: routeMode.label,
    travelMode: routeMode.travelMode,
    transitModes: routeMode.transitModes,
    from: {
      latitude: fromLatitude,
      longitude: fromLongitude,
    },
    to: {
      latitude: toLatitude,
      longitude: toLongitude,
    },
    distanceMeters,
    durationSeconds,
    estimatedWalkingSeconds: durationSeconds,
    duration: route.duration ?? "",
    path,
  };
  await cacheRepository.setCachedValue("routes", cacheKey, data, {
    metadata: { provider: "google-routes", mode: routeMode.mode },
  });
  return data;
}

/**
 * Fetches the walking route data.
 */
async function fetchWalkingRoute(coordinates) {
  return fetchRoute({ ...coordinates, mode: "walk" });
}

/**
 * Builds the route request payload.
 */
function buildRouteRequest({
  fromLatitude,
  fromLongitude,
  toLatitude,
  toLongitude,
  routeMode,
}) {
  const request = {
    origin: {
      location: {
        latLng: {
          latitude: fromLatitude,
          longitude: fromLongitude,
        },
      },
    },
    destination: {
      location: {
        latLng: {
          latitude: toLatitude,
          longitude: toLongitude,
        },
      },
    },
    travelMode: routeMode.travelMode,
    polylineQuality: "HIGH_QUALITY",
    units: "METRIC",
  };

  return request;
}

/**
 * Supports the route mode config backend flow.
 */
function routeModeConfig(value) {
  const normalized = String(value ?? "").trim().toLowerCase();
  const aliases = {
    walking: "walk",
    vehicle: "car",
    drive: "car",
    driving: "car",
  };
  const key = aliases[normalized] ?? normalized;
  return ROUTE_MODES[key] ?? ROUTE_MODES.walk;
}

/**
 * Reads the api key value from configuration or input.
 */
function readApiKey() {
  const apiKey = [
    process.env.GOOGLE_ROUTES_API_KEY,
    process.env.GOOGLE_MAPS_API_KEY,
    process.env.GOOGLE_PLACES_API_KEY,
  ]
    .map((value) => String(value ?? "").trim())
    .find((value) => value.length > 0 && !value.startsWith("your_"));

  if (!apiKey) {
    throw new HttpError(
      503,
      "GOOGLE_ROUTES_API_KEY is not configured for Google Maps Routes API routes.",
    );
  }

  return apiKey;
}

/**
 * Validates the coordinates input.
 */
function validateCoordinates(latitude, longitude, label) {
  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
    throw new HttpError(
      400,
      `${label} latitude must be a valid number between -90 and 90.`,
    );
  }
  if (!Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    throw new HttpError(
      400,
      `${label} longitude must be a valid number between -180 and 180.`,
    );
  }
}

/**
 * Builds the route cache key payload.
 */
function buildRouteCacheKey({
  fromLatitude,
  fromLongitude,
  toLatitude,
  toLongitude,
  mode,
}) {
  return [
    mode,
    Number(fromLatitude).toFixed(5),
    Number(fromLongitude).toFixed(5),
    Number(toLatitude).toFixed(5),
    Number(toLongitude).toFixed(5),
  ].join(",");
}

/**
 * Extracts the route error value from a provider response.
 */
function extractRouteError(body, status) {
  if (
    typeof body.error?.message === "string" &&
    body.error.message.trim().length > 0
  ) {
    return body.error.message;
  }
  if (typeof body.message === "string" && body.message.trim().length > 0) {
    return body.message;
  }
  if (typeof body.code === "string" && body.code.trim().length > 0) {
    return `Google Routes API lookup failed: ${body.code}.`;
  }
  return `Google Routes API lookup returned status ${status}.`;
}

/**
 * Parses the duration seconds value into the backend format.
 */
function parseDurationSeconds(value) {
  const match = String(value ?? "").match(/^(\d+(?:\.\d+)?)s$/);
  if (!match) {
    return 0;
  }
  return Math.round(Number(match[1]));
}

/**
 * Decodes the polyline value.
 */
function decodePolyline(encoded) {
  if (typeof encoded !== "string" || encoded.length === 0) {
    return [];
  }
  const points = [];
  let index = 0;
  let latitude = 0;
  let longitude = 0;

  while (index < encoded.length) {
    const latitudeDelta = decodePolylineValue(encoded, index);
    index = latitudeDelta.nextIndex;
    latitude += latitudeDelta.value;

    const longitudeDelta = decodePolylineValue(encoded, index);
    index = longitudeDelta.nextIndex;
    longitude += longitudeDelta.value;

    const decodedLatitude = latitude / 100000;
    const decodedLongitude = longitude / 100000;
    if (
      !Number.isFinite(decodedLatitude) ||
      decodedLatitude < -90 ||
      decodedLatitude > 90 ||
      !Number.isFinite(decodedLongitude) ||
      decodedLongitude < -180 ||
      decodedLongitude > 180
    ) {
      throw new HttpError(
        502,
        "Google Routes API returned a malformed route path.",
      );
    }
    points.push({
      latitude: decodedLatitude,
      longitude: decodedLongitude,
    });
  }

  return points;
}

/**
 * Decodes the polyline value value.
 */
function decodePolylineValue(encoded, startIndex) {
  let result = 0;
  let shift = 0;
  let currentIndex = startIndex;

  while (true) {
    if (currentIndex >= encoded.length || shift > 30) {
      throw new HttpError(
        502,
        "Google Routes API returned a truncated route path.",
      );
    }
    const characterCode = encoded.charCodeAt(currentIndex);
    if (characterCode < 63 || characterCode > 126) {
      throw new HttpError(
        502,
        "Google Routes API returned an invalid route path.",
      );
    }
    const byte = characterCode - 63;
    result |= (byte & 0x1f) << shift;
    shift += 5;
    currentIndex += 1;
    if (byte < 0x20) {
      break;
    }
  }

  const value = (result & 1) !== 0 ? ~(result >> 1) : result >> 1;
  return {
    value,
    nextIndex: currentIndex,
  };
}

module.exports = {
  decodePolyline,
  fetchRoute,
  fetchWalkingRoute,
};
