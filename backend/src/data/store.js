const seedTrips = [
  {
    id: "trip_001",
    destinationName: "Tokyo",
    destinationCountry: "Japan",
    latitude: 35.6762,
    longitude: 139.6503,
    startDate: "2026-07-12",
    endDate: "2026-07-18",
    preferences: ["culture", "food"],
    travelNotes: "Visit cultural places and try local restaurants.",
  },
  {
    id: "trip_002",
    destinationName: "Bangkok",
    destinationCountry: "Thailand",
    latitude: 13.7563,
    longitude: 100.5018,
    startDate: "2026-08-04",
    endDate: "2026-08-10",
    preferences: ["shopping", "food"],
    travelNotes: "Street food crawl and night market visits.",
  },
  {
    id: "trip_003",
    destinationName: "Seoul",
    destinationCountry: "South Korea",
    latitude: 37.5665,
    longitude: 126.978,
    startDate: "2026-09-01",
    endDate: "2026-09-07",
    preferences: ["culture", "family"],
    travelNotes: "Palaces, museums, and family-friendly attractions.",
  },
];

const seedSummaryByTrip = {
  trip_001: {
    weather: {
      temperature: 27,
      condition: "Cloudy",
      humidity: 70,
      windSpeed: 3.2,
    },
    googlePlaces: [
      {
        name: "Tokyo Tower",
        address: "Tokyo, Japan",
        rating: 4.5,
        type: "tourist_attraction",
      },
      {
        name: "Shibuya Crossing",
        address: "Shibuya, Tokyo",
        rating: 4.7,
        type: "landmark",
      },
      {
        name: "Ueno Park",
        address: "Taito, Tokyo",
        rating: 4.6,
        type: "park",
      },
    ],
    recommendations: [
      {
        name: "Senso-ji Temple",
        category: "Temple",
        distanceMeters: 3500,
        address: "Asakusa, Tokyo",
      },
      {
        name: "Tsukiji Market",
        category: "Market",
        distanceMeters: 4700,
        address: "Chuo, Tokyo",
      },
      {
        name: "Local Ramen Spot",
        category: "Restaurant",
        distanceMeters: 1200,
        address: "Shinjuku, Tokyo",
      },
    ],
    countryInfo: {
      country: "Japan",
      capital: "Tokyo",
      currency: "Japanese Yen",
      languages: ["Japanese"],
      region: "Asia",
      flag: "Japan",
    },
  },
  trip_002: {
    weather: {
      temperature: 31,
      condition: "Light Rain",
      humidity: 78,
      windSpeed: 2.8,
    },
    googlePlaces: [
      {
        name: "Wat Arun",
        address: "Bangkok, Thailand",
        rating: 4.6,
        type: "temple",
      },
      {
        name: "Chatuchak Market",
        address: "Bangkok, Thailand",
        rating: 4.4,
        type: "market",
      },
      {
        name: "ICONSIAM",
        address: "Bangkok, Thailand",
        rating: 4.5,
        type: "shopping_mall",
      },
    ],
    recommendations: [
      {
        name: "Yaowarat Street Food",
        category: "Food",
        distanceMeters: 1900,
        address: "Chinatown, Bangkok",
      },
      {
        name: "Siam Night Market",
        category: "Shopping",
        distanceMeters: 2300,
        address: "Pathum Wan, Bangkok",
      },
    ],
    countryInfo: {
      country: "Thailand",
      capital: "Bangkok",
      currency: "Thai Baht",
      languages: ["Thai"],
      region: "Asia",
      flag: "Thailand",
    },
  },
  trip_003: {
    weather: {
      temperature: 24,
      condition: "Clear",
      humidity: 60,
      windSpeed: 2.1,
    },
    googlePlaces: [
      {
        name: "Gyeongbokgung Palace",
        address: "Seoul, South Korea",
        rating: 4.7,
        type: "palace",
      },
      {
        name: "N Seoul Tower",
        address: "Seoul, South Korea",
        rating: 4.6,
        type: "landmark",
      },
      {
        name: "Lotte World",
        address: "Seoul, South Korea",
        rating: 4.5,
        type: "family_attraction",
      },
    ],
    recommendations: [
      {
        name: "Bukchon Hanok Village",
        category: "Culture",
        distanceMeters: 2100,
        address: "Jongno, Seoul",
      },
      {
        name: "COEX Aquarium",
        category: "Family",
        distanceMeters: 5400,
        address: "Gangnam, Seoul",
      },
    ],
    countryInfo: {
      country: "South Korea",
      capital: "Seoul",
      currency: "South Korean Won",
      languages: ["Korean"],
      region: "Asia",
      flag: "South Korea",
    },
  },
};

const bcrypt = require("bcryptjs");

const seedUsers = [
  {
    id: "user_001",
    name: "Demo User",
    email: "demo@travel.local",
    // Hash the seed password so bcrypt.compare() works during login
    password: bcrypt.hashSync("demo1234", 10),
  },
];

let trips = deepClone(seedTrips);
let summaryByTrip = deepClone(seedSummaryByTrip);
let users = deepClone(seedUsers);

function deepClone(value) {
  return JSON.parse(JSON.stringify(value));
}

function generateTripId() {
  const maxNumber = trips.reduce((max, trip) => {
    const value = Number(trip.id.replace("trip_", ""));
    if (Number.isNaN(value)) {
      return max;
    }
    return Math.max(max, value);
  }, 0);
  return `trip_${String(maxNumber + 1).padStart(3, "0")}`;
}

function listTrips() {
  return deepClone(trips);
}

function getTripById(id) {
  const trip = trips.find((item) => item.id === id);
  return trip ? deepClone(trip) : null;
}

function createTrip(payload) {
  const created = {
    id: generateTripId(),
    destinationName: String(payload.destinationName).trim(),
    destinationCountry: String(payload.destinationCountry).trim(),
    latitude: Number(payload.latitude),
    longitude: Number(payload.longitude),
    startDate: String(payload.startDate),
    endDate: String(payload.endDate),
    preferences: Array.isArray(payload.preferences)
      ? payload.preferences.map((value) => String(value))
      : [],
    travelNotes: String(payload.travelNotes ?? ""),
  };

  trips.push(created);
  summaryByTrip[created.id] = buildFallbackSummary(created);
  return deepClone(created);
}

function updateTrip(id, payload) {
  const index = trips.findIndex((item) => item.id === id);
  if (index < 0) {
    return null;
  }

  const current = trips[index];
  const updated = {
    ...current,
    destinationName:
      payload.destinationName !== undefined
        ? String(payload.destinationName).trim()
        : current.destinationName,
    destinationCountry:
      payload.destinationCountry !== undefined
        ? String(payload.destinationCountry).trim()
        : current.destinationCountry,
    latitude: payload.latitude !== undefined ? Number(payload.latitude) : current.latitude,
    longitude: payload.longitude !== undefined ? Number(payload.longitude) : current.longitude,
    startDate: payload.startDate !== undefined ? String(payload.startDate) : current.startDate,
    endDate: payload.endDate !== undefined ? String(payload.endDate) : current.endDate,
    preferences:
      payload.preferences !== undefined
        ? Array.isArray(payload.preferences)
          ? payload.preferences.map((value) => String(value))
          : []
        : current.preferences,
    travelNotes:
      payload.travelNotes !== undefined
        ? String(payload.travelNotes)
        : current.travelNotes,
  };

  trips[index] = updated;
  summaryByTrip[id] = buildFallbackSummary(updated);
  return deepClone(updated);
}

function deleteTrip(id) {
  const before = trips.length;
  trips = trips.filter((item) => item.id !== id);
  delete summaryByTrip[id];
  return trips.length < before;
}

function getTripWeather(id) {
  const summary = getTripSummarySeed(id);
  return deepClone(summary.weather);
}

function getTripGooglePlaces(id) {
  const summary = getTripSummarySeed(id);
  return deepClone(summary.googlePlaces);
}

function getTripRecommendations(id) {
  const summary = getTripSummarySeed(id);
  return deepClone(summary.recommendations);
}

function getTripCountryInfo(id) {
  const summary = getTripSummarySeed(id);
  return deepClone(summary.countryInfo);
}

function getTripSummary(id) {
  const trip = getTripById(id);
  if (!trip) {
    return null;
  }

  const summary = getTripSummarySeed(id);
  return {
    trip,
    weather: deepClone(summary.weather),
    googlePlaces: deepClone(summary.googlePlaces),
    recommendations: deepClone(summary.recommendations),
    countryInfo: deepClone(summary.countryInfo),
  };
}

function getTripSummarySeed(id) {
  if (!summaryByTrip[id]) {
    const trip = getTripById(id);
    summaryByTrip[id] = buildFallbackSummary(trip);
  }
  return summaryByTrip[id];
}

function buildFallbackSummary(trip) {
  if (!trip) {
    return {
      weather: {
        temperature: 25,
        condition: "Partly Cloudy",
        humidity: 65,
        windSpeed: 2.5,
      },
      googlePlaces: [],
      recommendations: [],
      countryInfo: {
        country: "Unknown",
        capital: "Unknown",
        currency: "Unknown",
        languages: [],
        region: "Unknown",
        flag: "Unknown",
      },
    };
  }

  const roundedLat = Number(trip.latitude.toFixed(4));
  const roundedLng = Number(trip.longitude.toFixed(4));

  return {
    weather: {
      temperature: 26,
      condition: "Partly Cloudy",
      humidity: 68,
      windSpeed: 2.7,
    },
    googlePlaces: [
      {
        name: `${trip.destinationName} Central Spot`,
        address: `${trip.destinationName}, ${trip.destinationCountry}`,
        rating: 4.4,
        type: "landmark",
      },
      {
        name: `${trip.destinationName} Food Area`,
        address: `${trip.destinationName}, ${trip.destinationCountry}`,
        rating: 4.3,
        type: "food",
      },
    ],
    recommendations: [
      {
        name: `${trip.destinationName} Local Walk`,
        category: "Culture",
        distanceMeters: 1800,
        address: `${trip.destinationName}, ${trip.destinationCountry}`,
      },
      {
        name: `${trip.destinationName} Family Area`,
        category: "Family",
        distanceMeters: 3200,
        address: `${trip.destinationName}, ${trip.destinationCountry}`,
      },
    ],
    countryInfo: {
      country: trip.destinationCountry,
      capital: "Not configured",
      currency: "Not configured",
      languages: [],
      region: "Not configured",
      flag: `${trip.destinationCountry} (${roundedLat}, ${roundedLng})`,
    },
  };
}

function getUserByEmail(email) {
  return users.find((user) => user.email.toLowerCase() === email.toLowerCase()) ?? null;
}

function getUserById(userId) {
  return users.find((user) => user.id === userId) ?? null;
}

function createUser(payload) {
  const created = {
    id: `user_${String(users.length + 1).padStart(3, "0")}`,
    name: String(payload.name).trim(),
    email: String(payload.email).trim().toLowerCase(),
    password: String(payload.password),
  };
  users.push(created);
  return {
    id: created.id,
    name: created.name,
    email: created.email,
  };
}

module.exports = {
  listTrips,
  getTripById,
  createTrip,
  updateTrip,
  deleteTrip,
  getTripWeather,
  getTripGooglePlaces,
  getTripRecommendations,
  getTripCountryInfo,
  getTripSummary,
  getUserByEmail,
  getUserById,
  createUser,
};
