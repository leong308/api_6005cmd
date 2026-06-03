const { HttpError } = require("../lib/http");

const GOOGLE_ROUTES_URL =
  process.env.GOOGLE_ROUTES_API_URL ||
  "https://routes.googleapis.com/directions/v2:computeRoutes";
const GOOGLE_ROUTES_FIELD_MASK =
  "routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline";
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

  const response = await fetch(GOOGLE_ROUTES_URL, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      "X-Goog-Api-Key": readApiKey(),
      "X-Goog-FieldMask": GOOGLE_ROUTES_FIELD_MASK,
    },
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

  return {
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
}

async function fetchWalkingRoute(coordinates) {
  return fetchRoute({ ...coordinates, mode: "walk" });
}

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

function parseDurationSeconds(value) {
  const match = String(value ?? "").match(/^(\d+(?:\.\d+)?)s$/);
  if (!match) {
    return 0;
  }
  return Math.round(Number(match[1]));
}

function decodePolyline(encoded) {
  const points = [];
  let index = 0;
  let latitude = 0;
  let longitude = 0;

  while (index < encoded.length) {
    const latitudeDelta = decodePolylineValue(encoded, () => index++);
    index = latitudeDelta.nextIndex;
    latitude += latitudeDelta.value;

    const longitudeDelta = decodePolylineValue(encoded, () => index++);
    index = longitudeDelta.nextIndex;
    longitude += longitudeDelta.value;

    points.push({
      latitude: latitude / 100000,
      longitude: longitude / 100000,
    });
  }

  return points;
}

function decodePolylineValue(encoded, nextIndex) {
  let result = 0;
  let shift = 0;
  let byte = null;
  let currentIndex = null;

  do {
    currentIndex = nextIndex();
    byte = encoded.charCodeAt(currentIndex) - 63;
    result |= (byte & 0x1f) << shift;
    shift += 5;
  } while (byte >= 0x20);

  const value = (result & 1) !== 0 ? ~(result >> 1) : result >> 1;
  return {
    value,
    nextIndex: currentIndex + 1,
  };
}

module.exports = {
  fetchRoute,
  fetchWalkingRoute,
};
