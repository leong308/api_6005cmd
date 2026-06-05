/**
 * Open-Meteo weather service.
 *
 * This file fetches current weather and daily forecasts from Open-Meteo,
 * validates coordinates/date ranges, caches provider responses briefly, and
 * maps weather codes into labels/icons used by the Flutter UI.
 */
const { HttpError } = require("../lib/http");

const OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast";
const CACHE_TTL_MS = 10 * 60 * 1000;

const CURRENT_FIELDS = [
  "temperature_2m",
  "relative_humidity_2m",
  "apparent_temperature",
  "weather_code",
  "wind_speed_10m",
  "pressure_msl",
];

const DAILY_FIELDS = [
  "weather_code",
  "temperature_2m_max",
  "temperature_2m_min",
  "apparent_temperature_max",
  "apparent_temperature_min",
  "precipitation_sum",
  "precipitation_probability_max",
  "wind_speed_10m_max",
];

const currentCache = new Map();
const dailyForecastCache = new Map();

function cacheKey(latitude, longitude) {
  return `${latitude.toFixed(4)},${longitude.toFixed(4)}`;
}

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

async function fetchCurrentWeather(latitude, longitude) {
  validateCoordinates(latitude, longitude);

  const key = cacheKey(latitude, longitude);
  const cached = currentCache.get(key);
  if (cached && cached.expiresAt > Date.now()) {
    return cached.data;
  }

  const url = new URL(OPEN_METEO_URL);
  url.searchParams.set("latitude", latitude);
  url.searchParams.set("longitude", longitude);
  url.searchParams.set("current", CURRENT_FIELDS.join(","));
  url.searchParams.set("temperature_unit", "celsius");
  url.searchParams.set("wind_speed_unit", "ms");
  url.searchParams.set("timezone", "auto");

  const response = await fetch(url);
  const body = await response.json().catch(() => ({}));

  if (!response.ok) {
    const message =
      typeof body.reason === "string" && body.reason.trim().length > 0
        ? body.reason
        : `Open-Meteo returned status ${response.status}.`;
    throw new HttpError(response.status, message);
  }

  const current = body.current ?? {};
  const units = body.current_units ?? {};
  const weatherCode = Number(current.weather_code);
  const data = {
    latitude,
    longitude,
    temperature: readNumber(current.temperature_2m),
    feelsLike: readNumber(current.apparent_temperature),
    condition: describeWeatherCode(weatherCode),
    conditionMain: weatherCodeToGroup(weatherCode),
    iconCode: weatherCodeToIcon(weatherCode),
    humidity: readNumber(current.relative_humidity_2m),
    windSpeed: readNumber(current.wind_speed_10m),
    pressure: readNumber(current.pressure_msl),
    observedAt: current.time ? String(current.time) : null,
    cityName: "",
    countryCode: "",
    timezone: body.timezone ?? "",
    elevation: readNumber(body.elevation),
    units: units.temperature_2m === "\u00B0F" ? "imperial" : "metric",
  };

  currentCache.set(key, {
    data,
    expiresAt: Date.now() + CACHE_TTL_MS,
  });

  return data;
}

async function fetchDailyForecast(latitude, longitude, startDate, endDate) {
  validateCoordinates(latitude, longitude);
  const normalizedStartDate = parseIsoDate(startDate, "startDate");
  const normalizedEndDate = parseIsoDate(endDate, "endDate");
  validateDateRange(normalizedStartDate, normalizedEndDate);

  const key = `${cacheKey(latitude, longitude)},${normalizedStartDate},${normalizedEndDate}`;
  const cached = dailyForecastCache.get(key);
  if (cached && cached.expiresAt > Date.now()) {
    return cached.data;
  }

  const url = new URL(OPEN_METEO_URL);
  url.searchParams.set("latitude", latitude);
  url.searchParams.set("longitude", longitude);
  url.searchParams.set("daily", DAILY_FIELDS.join(","));
  url.searchParams.set("temperature_unit", "celsius");
  url.searchParams.set("wind_speed_unit", "ms");
  url.searchParams.set("timezone", "auto");
  url.searchParams.set("start_date", normalizedStartDate);
  url.searchParams.set("end_date", normalizedEndDate);

  const response = await fetch(url);
  const body = await response.json().catch(() => ({}));

  if (!response.ok) {
    const message =
      typeof body.reason === "string" && body.reason.trim().length > 0
        ? body.reason
        : `Open-Meteo daily forecast returned status ${response.status}.`;
    throw new HttpError(response.status, message);
  }

  const daily = body.daily ?? {};
  const dates = Array.isArray(daily.time) ? daily.time : [];
  const forecast = dates.map((date, index) => {
    const weatherCode = Number(daily.weather_code?.[index]);
    return {
      date: String(date),
      condition: describeWeatherCode(weatherCode),
      conditionMain: weatherCodeToGroup(weatherCode),
      iconCode: weatherCodeToIcon(weatherCode),
      temperatureMax: readNumber(daily.temperature_2m_max?.[index]),
      temperatureMin: readNumber(daily.temperature_2m_min?.[index]),
      apparentTemperatureMax: readNumber(
        daily.apparent_temperature_max?.[index],
      ),
      apparentTemperatureMin: readNumber(
        daily.apparent_temperature_min?.[index],
      ),
      precipitationSum: readNumber(daily.precipitation_sum?.[index]),
      precipitationProbabilityMax: readNumber(
        daily.precipitation_probability_max?.[index],
      ),
      windSpeedMax: readNumber(daily.wind_speed_10m_max?.[index]),
    };
  });

  const data = {
    latitude,
    longitude,
    startDate: normalizedStartDate,
    endDate: normalizedEndDate,
    timezone: body.timezone ?? "",
    units: "metric",
    message: "",
    daily: forecast,
  };

  dailyForecastCache.set(key, {
    data,
    expiresAt: Date.now() + CACHE_TTL_MS,
  });

  return data;
}

function parseIsoDate(value, fieldName) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new HttpError(400, `${fieldName} must use YYYY-MM-DD format.`);
  }

  const parsed = new Date(`${value}T00:00:00.000Z`);
  if (
    Number.isNaN(parsed.getTime()) ||
    parsed.toISOString().slice(0, 10) !== value
  ) {
    throw new HttpError(400, `${fieldName} must be a valid calendar date.`);
  }

  return value;
}

function validateDateRange(startDate, endDate) {
  const start = new Date(`${startDate}T00:00:00.000Z`);
  const end = new Date(`${endDate}T00:00:00.000Z`);
  if (end < start) {
    throw new HttpError(400, "endDate must not be earlier than startDate.");
  }
}

function readNumber(value) {
  return Number.isFinite(value) ? value : null;
}

function describeWeatherCode(code) {
  return WEATHER_CODE_DESCRIPTIONS[code] ?? "Unavailable";
}

function weatherCodeToGroup(code) {
  if ([0, 1, 2].includes(code)) {
    return "Clear";
  }
  if ([3, 45, 48].includes(code)) {
    return "Clouds";
  }
  if ([51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82].includes(code)) {
    return "Rain";
  }
  if ([71, 73, 75, 77, 85, 86].includes(code)) {
    return "Snow";
  }
  if ([95, 96, 99].includes(code)) {
    return "Thunderstorm";
  }
  return "";
}

function weatherCodeToIcon(code) {
  if ([0, 1].includes(code)) {
    return "clear";
  }
  if ([2, 3].includes(code)) {
    return "cloudy";
  }
  if ([45, 48].includes(code)) {
    return "fog";
  }
  if ([51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82].includes(code)) {
    return "rain";
  }
  if ([71, 73, 75, 77, 85, 86].includes(code)) {
    return "snow";
  }
  if ([95, 96, 99].includes(code)) {
    return "storm";
  }
  return "";
}

const WEATHER_CODE_DESCRIPTIONS = {
  0: "Clear sky",
  1: "Mainly clear",
  2: "Partly cloudy",
  3: "Overcast",
  45: "Fog",
  48: "Depositing rime fog",
  51: "Light drizzle",
  53: "Moderate drizzle",
  55: "Dense drizzle",
  56: "Light freezing drizzle",
  57: "Dense freezing drizzle",
  61: "Slight rain",
  63: "Moderate rain",
  65: "Heavy rain",
  66: "Light freezing rain",
  67: "Heavy freezing rain",
  71: "Slight snow fall",
  73: "Moderate snow fall",
  75: "Heavy snow fall",
  77: "Snow grains",
  80: "Slight rain showers",
  81: "Moderate rain showers",
  82: "Violent rain showers",
  85: "Slight snow showers",
  86: "Heavy snow showers",
  95: "Thunderstorm",
  96: "Thunderstorm with slight hail",
  99: "Thunderstorm with heavy hail",
};

module.exports = {
  fetchCurrentWeather,
  fetchDailyForecast,
};
