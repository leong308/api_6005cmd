/**
 * Trip agenda service.
 *
 * This file builds a timed travel plan from trip dates, weather forecasts,
 * recommendation groups, venue availability checks, and route-map previews. It
 * is used by the summary endpoint and `/api/trips/:id/agenda` to create a
 * day-by-day itinerary with food/place slots and walking route data.
 */
const foursquareService = require("./foursquareService");
const routeService = require("./routeService");

const AGENDA_PATTERN = [
  {
    slot: "breakfast",
    kind: "food",
    timeOfDay: "Breakfast",
    startTime: "08:30",
    endTime: "09:30",
    preference: "food",
  },
  {
    slot: "morning-place",
    kind: "place",
    timeOfDay: "Morning Place",
    startTime: "10:00",
    endTime: "12:00",
  },
  {
    slot: "lunch",
    kind: "food",
    timeOfDay: "Lunch",
    startTime: "12:30",
    endTime: "13:45",
    preference: "food",
  },
  {
    slot: "afternoon-place",
    kind: "place",
    timeOfDay: "Afternoon Place",
    startTime: "14:15",
    endTime: "16:00",
  },
  {
    slot: "late-afternoon-place",
    kind: "place",
    timeOfDay: "Local Stop",
    startTime: "16:30",
    endTime: "18:00",
  },
  {
    slot: "dinner",
    kind: "food",
    timeOfDay: "Dinner",
    startTime: "19:00",
    endTime: "20:30",
    preference: "food",
  },
  {
    slot: "evening-place",
    kind: "place",
    timeOfDay: "Evening Place",
    startTime: "21:00",
    endTime: "22:15",
  },
];
const DEFAULT_PLACE_PREFERENCES = ["culture", "nature", "shopping", "family"];
const MAX_AGENDA_DAYS = 21;
const DEFAULT_AVAILABILITY_DAYS = 1;
const MAX_AVAILABILITY_DAYS = 7;
const DEFAULT_ROUTE_MAP_DAYS = 0;
const MAX_ROUTE_MAP_DAYS = MAX_AGENDA_DAYS;
const SLOT_RESULT_LIMIT = 10;
const MAX_PARALLEL_FOURSQUARE_REQUESTS = 6;
const MAX_PARALLEL_ROUTE_DAYS = 2;
const MAX_PARALLEL_ROUTE_LEGS = 3;
const WALKING_METERS_PER_SECOND = 1.35;
const AGENDA_ROUTE_COLORS = [
  "#2563eb",
  "#f97316",
  "#16a34a",
  "#a855f7",
  "#0891b2",
  "#e11d48",
  "#ca8a04",
];
const routeCache = new Map();

async function buildTimedTripAgenda({
  trip,
  dailyWeatherForecast,
  recommendationGroups = [],
  availabilityDays = DEFAULT_AVAILABILITY_DAYS,
  routeMapDays = DEFAULT_ROUTE_MAP_DAYS,
  routeMapDayIndexes = [],
}) {
  const dates = tripDates(trip.startDate, trip.endDate);
  const forecastByDate = new Map(
    (dailyWeatherForecast?.daily ?? []).map((day) => [day.date, day]),
  );
  const scheduledSlots = buildScheduledSlots(trip, dates);
  const availabilityDayLimit = clampAvailabilityDays(availabilityDays);
  const availabilityDates = new Set(dates.slice(0, availabilityDayLimit));
  const requestMap = buildRequestMap(
    scheduledSlots.filter((slot) => availabilityDates.has(slot.date)),
  );
  const availabilityPools = await fetchAvailabilityPools({
    latitude: trip.latitude,
    longitude: trip.longitude,
    requestMap,
  });
  const fallbackRecommendations = flattenRecommendations(recommendationGroups);
  const usedIds = new Set();
  const days = dates.map((date, dayIndex) =>
    buildAgendaDay({
      date,
      dayIndex,
      trip,
      forecast: forecastByDate.get(date),
      scheduledSlots: scheduledSlots.filter((slot) => slot.date === date),
      availabilityPools,
      fallbackRecommendations,
      usedIds,
    }),
  );

  return {
    title: "Open-now timed tour guide",
    generatedAt: new Date().toISOString(),
    tripDays: dates.length,
    pattern: "food - place - food - place - place - food - place",
    source: {
      weather: "open-meteo",
      recommendations: "foursquare with Geoapify Places fallback",
      availability: "foursquare open_at filter with Geoapify fallback",
      strategy:
        "food/place rhythm + date + preference + weather rotation + capped live open-at checks",
    },
    days: await enrichAgendaDaysWithRouteMaps({
      trip,
      days,
      routeMapDays,
      routeMapDayIndexes,
    }),
    checklist: buildChecklist(trip),
  };
}

async function buildTripAgenda({
  trip,
  dailyWeatherForecast,
  recommendationGroups,
  routeMapDays = DEFAULT_ROUTE_MAP_DAYS,
  routeMapDayIndexes = [],
}) {
  const dates = tripDates(trip.startDate, trip.endDate);
  const forecastByDate = new Map(
    (dailyWeatherForecast?.daily ?? []).map((day) => [day.date, day]),
  );
  const recommendations = flattenRecommendations(recommendationGroups);
  const usedIds = new Set();
  const days = dates.map((date, dayIndex) =>
    buildAgendaDay({
      date,
      dayIndex,
      trip,
      forecast: forecastByDate.get(date),
      scheduledSlots: buildScheduledSlots(trip, [date]),
      availabilityPools: new Map(),
      fallbackRecommendations: recommendations,
      usedIds,
    }),
  );

  return {
    title: "Weather-aware tour guide",
    generatedAt: new Date().toISOString(),
    tripDays: dates.length,
    pattern: "food - place - food - place - place - food - place",
    source: {
      weather: "open-meteo",
      recommendations: "foursquare with Geoapify Places fallback",
      availability: "fallback recommendation rotation",
      strategy: "date + preference + weather rotation",
    },
    days: await enrichAgendaDaysWithRouteMaps({
      trip,
      days,
      routeMapDays,
      routeMapDayIndexes,
    }),
    checklist: buildChecklist(trip),
  };
}

function buildAgendaDay({
  date,
  dayIndex,
  trip,
  forecast,
  scheduledSlots,
  availabilityPools,
  fallbackRecommendations,
  usedIds,
}) {
  const weatherNote = weatherTip(forecast);

  return {
    date,
    label: `Day ${dayIndex + 1}`,
    theme: themeForPreference(
      scheduledSlots.find((slot) => slot.kind === "place")?.preference,
    ),
    weather: forecast
      ? {
          condition: forecast.condition,
          temperatureMin: forecast.temperatureMin,
          temperatureMax: forecast.temperatureMax,
          precipitationProbabilityMax: forecast.precipitationProbabilityMax,
        }
      : null,
    weatherNote,
    items: scheduledSlots.map((slot) =>
      buildAgendaItem({
        slot,
        recommendation: selectRecommendation({
          pool: availabilityPools.get(slot.requestKey) ?? [],
          fallbackRecommendations,
          preference: slot.preference,
          usedIds,
        }),
        weatherNote,
        trip,
      }),
    ),
  };
}

function buildAgendaItem({ slot, recommendation, weatherNote, trip }) {
  const visitWindow = `${slot.startTime} - ${slot.endTime}`;
  if (recommendation) {
    const verified = Boolean(
      recommendation.availability?.verifiedForVisitTime,
    );
    return {
      slot: slot.slot,
      kind: slot.kind,
      timeOfDay: slot.timeOfDay,
      startTime: slot.startTime,
      endTime: slot.endTime,
      visitWindow,
      title: recommendation.name,
      category: recommendation.category,
      preference: recommendation.preference ?? slot.preference,
      description: `${slot.timeOfDay} (${visitWindow}) for ${themeForPreference(slot.preference).toLowerCase()}. ${weatherNote}`,
      address: recommendation.address,
      coordinates: recommendation.coordinates,
      distanceMeters: recommendation.distanceMeters,
      availability: {
        openAt: slot.openAt,
        verifiedForVisitTime: verified,
        label: verified
          ? `Foursquare filtered this stop as open at ${slot.openAt}.`
          : "Opening-time filter unavailable; verify before visiting.",
        source: recommendation.availability?.source ?? "fallback",
      },
    };
  }

  return {
    slot: slot.slot,
    kind: slot.kind,
    timeOfDay: slot.timeOfDay,
    startTime: slot.startTime,
    endTime: slot.endTime,
    visitWindow,
    title: fallbackTitle(slot, trip.destinationName),
    category: slot.preference,
    preference: slot.preference,
    description: `${themeForPreference(slot.preference)} around ${trip.destinationName}. ${weatherNote}`,
    address: "",
    coordinates: {
      latitude: trip.latitude,
      longitude: trip.longitude,
    },
    distanceMeters: 0,
    availability: {
      openAt: slot.openAt,
      verifiedForVisitTime: false,
      label: "No open-at venue returned; use as a flexible backup slot.",
      source: "fallback",
    },
  };
}

async function enrichAgendaDaysWithRouteMaps({
  trip,
  days,
  routeMapDays,
  routeMapDayIndexes = [],
}) {
  const routeMapDayLimit = clampRouteMapDays(routeMapDays);
  const explicitRouteDays = new Set(
    routeMapDayIndexes
      .map((index) => Number(index))
      .filter((index) => Number.isInteger(index) && index >= 0),
  );
  return await mapWithConcurrencyResults(
    days,
    MAX_PARALLEL_ROUTE_DAYS,
    async (day, dayIndex) => {
      const shouldBuildRouteMap = explicitRouteDays.size > 0
        ? explicitRouteDays.has(dayIndex)
        : dayIndex < routeMapDayLimit;
      if (!shouldBuildRouteMap) {
        return {
          ...day,
          routeMap: buildUnavailableRouteMap({
            trip,
            day,
            message:
              "Press Get route for this day to generate its walking route map.",
          }),
        };
      }

      return {
        ...day,
        routeMap: await buildDayRouteMap({ trip, day }),
      };
    },
  );
}

async function buildDayRouteMap({ trip, day }) {
  const stops = agendaStopsForDay(trip, day);
  const legSpecs = buildLegSpecs(stops);
  const legs = await mapWithConcurrencyResults(
    legSpecs,
    MAX_PARALLEL_ROUTE_LEGS,
    fetchAgendaRouteLeg,
  );
  const totalDistanceMeters = legs.reduce(
    (total, leg) => total + (Number(leg.distanceMeters) || 0),
    0,
  );
  const totalDurationSeconds = legs.reduce(
    (total, leg) => total + (Number(leg.durationSeconds) || 0),
    0,
  );
  const routeAvailable = legs.some((leg) => leg.routeAvailable);
  const hasFallback = legs.some((leg) => !leg.routeAvailable);
  const hasLegs = legs.length > 0;

  return {
    mode: "walk",
    modeLabel: "Walk",
    provider: routeAvailable
      ? "google-routes"
      : hasLegs
        ? "fallback-straight-line"
        : "unavailable",
    routeAvailable,
    totalDistanceMeters,
    totalDurationSeconds,
    legCount: legs.length,
    stopCount: stops.length,
    markers: stops.map((stop, index) => ({
      label: index === 0 ? "Start" : String(index),
      title: stop.title,
      kind: stop.kind,
      timeOfDay: stop.timeOfDay,
      coordinates: stop.coordinates,
      color:
        index === 0
          ? "#2563eb"
          : AGENDA_ROUTE_COLORS[(index - 1) % AGENDA_ROUTE_COLORS.length],
    })),
    legs,
    message: !hasLegs
      ? "Route map needs at least one distinct venue coordinate from live recommendations."
      : hasFallback
        ? "Some legs use direct preview lines because Google Routes did not return a routable walking path."
        : "Walking paths generated by Google Routes API.",
  };
}

function buildUnavailableRouteMap({ trip, day, message }) {
  const stops = agendaStopsForDay(trip, day);
  return {
    mode: "walk",
    modeLabel: "Walk",
    provider: "unavailable",
    routeAvailable: false,
    totalDistanceMeters: 0,
    totalDurationSeconds: 0,
    legCount: 0,
    stopCount: stops.length,
    markers: stops.map((stop, index) => ({
      label: index === 0 ? "Start" : String(index),
      title: stop.title,
      kind: stop.kind,
      timeOfDay: stop.timeOfDay,
      coordinates: stop.coordinates,
      color:
        index === 0
          ? "#2563eb"
          : AGENDA_ROUTE_COLORS[(index - 1) % AGENDA_ROUTE_COLORS.length],
    })),
    legs: [],
    message,
  };
}

function agendaStopsForDay(trip, day) {
  return [
    {
      title: "Trip start",
      kind: "start",
      timeOfDay: "Start",
      coordinates: {
        latitude: Number(trip.latitude),
        longitude: Number(trip.longitude),
      },
    },
    ...day.items
      .map((item) => ({
        title: item.title,
        kind: item.kind,
        timeOfDay: item.timeOfDay,
        coordinates: {
          latitude: Number(item.coordinates?.latitude),
          longitude: Number(item.coordinates?.longitude),
        },
      }))
      .filter((stop) => isValidCoordinatePair(stop.coordinates)),
  ].filter((stop, index, stops) => {
    if (index === 0) {
      return isValidCoordinatePair(stop.coordinates);
    }
    const previous = stops[index - 1];
    return !sameCoordinates(stop.coordinates, previous.coordinates);
  });
}

function buildLegSpecs(stops) {
  const specs = [];
  for (let index = 1; index < stops.length; index += 1) {
    specs.push({
      legNumber: index,
      color: AGENDA_ROUTE_COLORS[(index - 1) % AGENDA_ROUTE_COLORS.length],
      from: stops[index - 1],
      to: stops[index],
    });
  }
  return specs;
}

async function fetchAgendaRouteLeg(spec) {
  const cacheKey = routeLegCacheKey(spec);
  if (routeCache.has(cacheKey)) {
    return routeCache.get(cacheKey);
  }

  try {
    const route = await routeService.fetchRoute({
      fromLatitude: spec.from.coordinates.latitude,
      fromLongitude: spec.from.coordinates.longitude,
      toLatitude: spec.to.coordinates.latitude,
      toLongitude: spec.to.coordinates.longitude,
      mode: "walk",
    });
    const leg = {
      legNumber: spec.legNumber,
      label: `${spec.from.title} to ${spec.to.title}`,
      fromTitle: spec.from.title,
      toTitle: spec.to.title,
      from: spec.from.coordinates,
      to: spec.to.coordinates,
      color: spec.color,
      provider: route.provider,
      mode: route.mode,
      modeLabel: route.modeLabel,
      travelMode: route.travelMode,
      routeAvailable: true,
      distanceMeters: route.distanceMeters,
      durationSeconds:
        Number(route.durationSeconds) ||
        Number(route.estimatedWalkingSeconds) ||
        0,
      path: route.path,
    };
    routeCache.set(cacheKey, leg);
    return leg;
  } catch (error) {
    console.error(
      `Agenda route leg failed (${spec.from.title} -> ${spec.to.title}): ${error.message}`,
    );
    const leg = buildFallbackRouteLeg(spec, error.message);
    routeCache.set(cacheKey, leg);
    return leg;
  }
}

function buildFallbackRouteLeg(spec, unavailableReason) {
  const distanceMeters = estimateDistanceMeters(
    spec.from.coordinates,
    spec.to.coordinates,
  );
  return {
    legNumber: spec.legNumber,
    label: `${spec.from.title} to ${spec.to.title}`,
    fromTitle: spec.from.title,
    toTitle: spec.to.title,
    from: spec.from.coordinates,
    to: spec.to.coordinates,
    color: spec.color,
    provider: "fallback-straight-line",
    mode: "walk",
    modeLabel: "Walk",
    travelMode: "WALK",
    routeAvailable: false,
    distanceMeters,
    durationSeconds: Math.ceil(distanceMeters / WALKING_METERS_PER_SECOND),
    path: [spec.from.coordinates, spec.to.coordinates],
    unavailableReason,
  };
}

function buildScheduledSlots(trip, dates) {
  const placePreferences = placePreferencesForTrip(trip.preferences);
  let placeIndex = 0;

  return dates.flatMap((date) =>
    AGENDA_PATTERN.map((slot) => {
      const preference =
        slot.kind === "food"
          ? "food"
          : placePreferences[placeIndex++ % placePreferences.length];
      const openAt = foursquareOpenAt(date, slot.startTime);
      const requestKey = `${preference}|${openAt}`;
      return {
        ...slot,
        date,
        preference,
        openAt,
        requestKey,
      };
    }),
  );
}

function buildRequestMap(scheduledSlots) {
  return scheduledSlots.reduce((requests, slot) => {
    if (!requests.has(slot.requestKey)) {
      requests.set(slot.requestKey, {
        preference: slot.preference,
        openAt: slot.openAt,
      });
    }
    return requests;
  }, new Map());
}

async function fetchAvailabilityPools({ latitude, longitude, requestMap }) {
  const requests = [...requestMap.entries()];
  const results = new Map();

  await mapWithConcurrency(
    requests,
    MAX_PARALLEL_FOURSQUARE_REQUESTS,
    async ([key, request]) => {
      try {
        const recommendations = await foursquareService.fetchRecommendations({
          latitude,
          longitude,
          preference: request.preference,
          limit: SLOT_RESULT_LIMIT,
          openAt: request.openAt,
        });
        results.set(
          key,
          recommendations.map((recommendation) => ({
            ...recommendation,
            preference: request.preference,
          })),
        );
      } catch (error) {
        console.error(
          `Agenda availability lookup failed for ${key}: ${error.message}`,
        );
        results.set(key, []);
      }
    },
  );

  return results;
}

async function mapWithConcurrency(items, limit, iterator) {
  const workers = Array.from({ length: Math.min(limit, items.length) }, async (
    _,
    workerIndex,
  ) => {
    for (let index = workerIndex; index < items.length; index += limit) {
      await iterator(items[index], index);
    }
  });
  await Promise.all(workers);
}

async function mapWithConcurrencyResults(items, limit, iterator) {
  const results = new Array(items.length);
  await mapWithConcurrency(items, limit, async (item, index) => {
    results[index] = await iterator(item, index);
  });
  return results;
}

function selectRecommendation({ pool, fallbackRecommendations, preference, usedIds }) {
  const candidates = pool.length > 0
    ? pool
    : fallbackRecommendations.filter(
        (recommendation) => recommendation.preference === preference,
      );
  const fallbackPool = candidates.length > 0 ? candidates : fallbackRecommendations;
  if (fallbackPool.length === 0) {
    return null;
  }

  const recommendation =
    fallbackPool.find((item) => !usedIds.has(recommendationId(item))) ??
    fallbackPool[0];
  usedIds.add(recommendationId(recommendation));
  return recommendation;
}

function recommendationId(recommendation) {
  return recommendation.id || recommendation.name || JSON.stringify(recommendation);
}

function routeLegCacheKey(spec) {
  return [
    "walk",
    coordinateKey(spec.from.coordinates),
    coordinateKey(spec.to.coordinates),
  ].join("|");
}

function coordinateKey(coordinates) {
  return `${Number(coordinates.latitude).toFixed(5)},${Number(
    coordinates.longitude,
  ).toFixed(5)}`;
}

function isValidCoordinatePair(coordinates) {
  return (
    Number.isFinite(coordinates?.latitude) &&
    coordinates.latitude >= -90 &&
    coordinates.latitude <= 90 &&
    Number.isFinite(coordinates?.longitude) &&
    coordinates.longitude >= -180 &&
    coordinates.longitude <= 180
  );
}

function sameCoordinates(first, second) {
  return (
    Math.abs(Number(first.latitude) - Number(second.latitude)) < 0.00001 &&
    Math.abs(Number(first.longitude) - Number(second.longitude)) < 0.00001
  );
}

function estimateDistanceMeters(from, to) {
  const earthRadiusMeters = 6371000;
  const lat1 = degreesToRadians(from.latitude);
  const lat2 = degreesToRadians(to.latitude);
  const deltaLat = degreesToRadians(to.latitude - from.latitude);
  const deltaLng = degreesToRadians(to.longitude - from.longitude);
  const a =
    Math.sin(deltaLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(deltaLng / 2) ** 2;
  return Math.round(
    earthRadiusMeters * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)),
  );
}

function degreesToRadians(value) {
  return (Number(value) * Math.PI) / 180;
}

function flattenRecommendations(recommendationGroups = []) {
  return recommendationGroups.flatMap((group) =>
    (group.recommendations ?? []).map((recommendation) => ({
      ...recommendation,
      preference: group.preference,
    })),
  );
}

function tripDates(startDate, endDate) {
  const start = parseDate(startDate);
  const end = parseDate(endDate);
  if (!start || !end || end < start) {
    return [];
  }

  const dates = [];
  const cursor = new Date(start);
  while (cursor <= end && dates.length < MAX_AGENDA_DAYS) {
    dates.push(cursor.toISOString().slice(0, 10));
    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }
  return dates;
}

function parseDate(value) {
  const date = new Date(`${value}T00:00:00.000Z`);
  return Number.isNaN(date.getTime()) ? null : date;
}

function foursquareOpenAt(date, time) {
  const parsed = parseDate(date);
  if (!parsed) {
    return "";
  }
  const day = parsed.getUTCDay();
  const foursquareDay = day === 0 ? 7 : day;
  return `${foursquareDay}T${time.replace(":", "")}`;
}

function placePreferencesForTrip(preferences = []) {
  const filtered = (Array.isArray(preferences) ? preferences : [])
    .map((preference) => String(preference).trim().toLowerCase())
    .filter((preference) => preference && preference !== "food");
  const unique = [...new Set(filtered)];
  return unique.length > 0 ? unique : DEFAULT_PLACE_PREFERENCES;
}

function weatherTip(forecast) {
  if (!forecast) {
    return "Check live weather before leaving.";
  }

  const rainChance = Number(forecast.precipitationProbabilityMax ?? 0);
  const condition = String(forecast.conditionMain || forecast.condition || "")
    .toLowerCase();

  if (rainChance >= 60 || condition.includes("rain") || condition.includes("storm")) {
    return "Keep indoor backups and carry rain protection.";
  }
  if (Number(forecast.temperatureMax) >= 34) {
    return "Plan outdoor stops earlier and keep hydration breaks.";
  }
  return "Good day for a balanced indoor and outdoor route.";
}

function themeForPreference(preference) {
  const normalized = String(preference ?? "").trim().toLowerCase();
  const labels = {
    food: "Food discovery",
    culture: "Culture and heritage",
    nature: "Nature break",
    shopping: "Shopping route",
    family: "Family-friendly pacing",
    adventure: "Adventure stop",
    history: "Historic route",
    arts: "Arts and creative spaces",
    outdoors: "Outdoor exploration",
    wellness: "Wellness reset",
    nightlife: "Evening nightlife",
  };
  return labels[normalized] ?? "Local discovery";
}

function fallbackTitle(slot, destinationName) {
  if (slot.kind === "food") {
    return `${destinationName} ${slot.timeOfDay.toLowerCase()} break`;
  }
  return `${destinationName} ${slot.timeOfDay.toLowerCase()}`;
}

function clampRouteMapDays(value) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed)) {
    return DEFAULT_ROUTE_MAP_DAYS;
  }
  return Math.min(Math.max(parsed, 0), MAX_ROUTE_MAP_DAYS);
}

function clampAvailabilityDays(value) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed)) {
    return DEFAULT_AVAILABILITY_DAYS;
  }
  return Math.min(Math.max(parsed, 0), MAX_AVAILABILITY_DAYS);
}

function buildChecklist(trip) {
  return [
    `Confirm transport from your stay to ${trip.destinationName}.`,
    "Save route maps before leaving.",
    "Check weather and rain chance each morning.",
    "Keep one flexible backup slot per day.",
    "Re-check opening hours on the travel day in case venues change schedules.",
  ];
}

module.exports = {
  buildTimedTripAgenda,
  buildTripAgenda,
};
