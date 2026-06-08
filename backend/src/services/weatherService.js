/**
 * Weather service with provider fallback.
 *
 * Open-Meteo remains the primary provider. If it fails or rate-limits, the
 * service falls back to OpenWeather, then MET Norway's free Locationforecast
 * API. Every provider is mapped into the app's existing weather response shape.
 */
const { HttpError } = require("../lib/http");

const PROVIDERS = {
  openMeteo: "open-meteo",
  openWeather: "openweather",
  metNorway: "met-norway",
};

const OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast";
const OPENWEATHER_CURRENT_URL =
  process.env.OPENWEATHER_CURRENT_URL ||
  "https://api.openweathermap.org/data/2.5/weather";
const OPENWEATHER_FORECAST_URL =
  process.env.OPENWEATHER_FORECAST_URL ||
  "https://api.openweathermap.org/data/2.5/forecast";
const MET_NORWAY_URL =
  process.env.MET_NORWAY_URL ||
  "https://api.met.no/weatherapi/locationforecast/2.0/compact";
const WEATHER_PROVIDER_TIMEOUT_MS = Number(
  process.env.WEATHER_PROVIDER_TIMEOUT_MS || 12000,
);
const MET_NORWAY_USER_AGENT =
  process.env.MET_NORWAY_USER_AGENT ||
  process.env.NOMINATIM_USER_AGENT ||
  "SmartTravelPlanner/1.0 (local-development)";
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

async function fetchCurrentWeather(latitude, longitude, options = {}) {
  validateCoordinates(latitude, longitude);

  const key = cacheKey(latitude, longitude);
  const cached = currentCache.get(key);
  if (!options.forceRefresh && cached && cached.expiresAt > Date.now()) {
    return cached.data;
  }

  const data = await fetchWithFallback("current weather", [
    {
      provider: PROVIDERS.openMeteo,
      fetcher: () => fetchOpenMeteoCurrentWeather(latitude, longitude),
    },
    {
      provider: PROVIDERS.openWeather,
      fetcher: () => fetchOpenWeatherCurrentWeather(latitude, longitude),
    },
    {
      provider: PROVIDERS.metNorway,
      fetcher: () => fetchMetNorwayCurrentWeather(latitude, longitude),
    },
  ]);

  currentCache.set(key, {
    data,
    expiresAt: Date.now() + CACHE_TTL_MS,
  });

  return data;
}

async function fetchDailyForecast(
  latitude,
  longitude,
  startDate,
  endDate,
  options = {},
) {
  validateCoordinates(latitude, longitude);
  const normalizedStartDate = parseIsoDate(startDate, "startDate");
  const normalizedEndDate = parseIsoDate(endDate, "endDate");
  validateDateRange(normalizedStartDate, normalizedEndDate);

  const key = `${cacheKey(latitude, longitude)},${normalizedStartDate},${normalizedEndDate}`;
  const cached = dailyForecastCache.get(key);
  if (!options.forceRefresh && cached && cached.expiresAt > Date.now()) {
    return cached.data;
  }

  const data = await fetchWithFallback("daily weather forecast", [
    {
      provider: PROVIDERS.openMeteo,
      fetcher: () =>
        fetchOpenMeteoDailyForecast(
          latitude,
          longitude,
          normalizedStartDate,
          normalizedEndDate,
        ),
    },
    {
      provider: PROVIDERS.openWeather,
      fetcher: () =>
        fetchOpenWeatherDailyForecast(
          latitude,
          longitude,
          normalizedStartDate,
          normalizedEndDate,
        ),
    },
    {
      provider: PROVIDERS.metNorway,
      fetcher: () =>
        fetchMetNorwayDailyForecast(
          latitude,
          longitude,
          normalizedStartDate,
          normalizedEndDate,
        ),
    },
  ]);

  dailyForecastCache.set(key, {
    data,
    expiresAt: Date.now() + CACHE_TTL_MS,
  });

  return data;
}

async function fetchWithFallback(label, providers) {
  const failures = [];

  for (const provider of providers) {
    try {
      const data = await provider.fetcher();
      return {
        ...data,
        provider: provider.provider,
        fallbackChain: providers.map((item) => item.provider),
      };
    } catch (error) {
      failures.push(`${provider.provider}: ${error.message}`);
      console.warn(
        `Weather provider failed (${provider.provider}, ${label}): ${error.message}`,
      );
    }
  }

  throw new HttpError(
    502,
    `All weather providers failed for ${label}. ${failures.join(" | ")}`,
  );
}

async function fetchOpenMeteoCurrentWeather(latitude, longitude) {
  const url = new URL(OPEN_METEO_URL);
  url.searchParams.set("latitude", latitude);
  url.searchParams.set("longitude", longitude);
  url.searchParams.set("current", CURRENT_FIELDS.join(","));
  url.searchParams.set("temperature_unit", "celsius");
  url.searchParams.set("wind_speed_unit", "ms");
  url.searchParams.set("timezone", "auto");

  const body = await fetchProviderJson(url, {
    provider: PROVIDERS.openMeteo,
    errorMessage: "Open-Meteo current weather failed",
    extractError: (json, status) =>
      typeof json.reason === "string" && json.reason.trim().length > 0
        ? json.reason
        : `Open-Meteo returned status ${status}.`,
  });

  const current = body.current ?? {};
  if (!body.current) {
    throw new HttpError(502, "Open-Meteo returned no current weather.");
  }

  const units = body.current_units ?? {};
  const weatherCode = Number(current.weather_code);
  return {
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
}

async function fetchOpenMeteoDailyForecast(
  latitude,
  longitude,
  startDate,
  endDate,
) {
  const url = new URL(OPEN_METEO_URL);
  url.searchParams.set("latitude", latitude);
  url.searchParams.set("longitude", longitude);
  url.searchParams.set("daily", DAILY_FIELDS.join(","));
  url.searchParams.set("temperature_unit", "celsius");
  url.searchParams.set("wind_speed_unit", "ms");
  url.searchParams.set("timezone", "auto");
  url.searchParams.set("start_date", startDate);
  url.searchParams.set("end_date", endDate);

  const body = await fetchProviderJson(url, {
    provider: PROVIDERS.openMeteo,
    errorMessage: "Open-Meteo daily forecast failed",
    extractError: (json, status) =>
      typeof json.reason === "string" && json.reason.trim().length > 0
        ? json.reason
        : `Open-Meteo daily forecast returned status ${status}.`,
  });

  const daily = body.daily ?? {};
  const dates = Array.isArray(daily.time) ? daily.time : [];
  if (dates.length === 0) {
    throw new HttpError(502, "Open-Meteo returned no daily forecast.");
  }

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

  return {
    latitude,
    longitude,
    startDate,
    endDate,
    timezone: body.timezone ?? "",
    units: "metric",
    message: "",
    daily: forecast,
  };
}

async function fetchOpenWeatherCurrentWeather(latitude, longitude) {
  const apiKey = readOpenWeatherApiKey();
  const url = new URL(OPENWEATHER_CURRENT_URL);
  url.searchParams.set("lat", latitude);
  url.searchParams.set("lon", longitude);
  url.searchParams.set("appid", apiKey);
  url.searchParams.set("units", "metric");
  url.searchParams.set("lang", "en");

  const body = await fetchProviderJson(url, {
    provider: PROVIDERS.openWeather,
    errorMessage: "OpenWeather current weather failed",
    extractError: extractOpenWeatherError,
  });

  const weather = firstWeather(body.weather);
  return {
    latitude,
    longitude,
    temperature: readNumber(body.main?.temp),
    feelsLike: readNumber(body.main?.feels_like),
    condition: normalizeOpenWeatherDescription(weather),
    conditionMain: normalizeOpenWeatherMain(weather?.main),
    iconCode: openWeatherIconToAppIcon(weather?.icon, weather?.main),
    humidity: readNumber(body.main?.humidity),
    windSpeed: readNumber(body.wind?.speed),
    pressure: readNumber(body.main?.pressure),
    observedAt: unixSecondsToIso(body.dt),
    cityName: String(body.name ?? ""),
    countryCode: String(body.sys?.country ?? ""),
    timezone: timezoneOffsetLabel(readNumber(body.timezone)),
    elevation: null,
    units: "metric",
  };
}

async function fetchOpenWeatherDailyForecast(
  latitude,
  longitude,
  startDate,
  endDate,
) {
  const apiKey = readOpenWeatherApiKey();
  const url = new URL(OPENWEATHER_FORECAST_URL);
  url.searchParams.set("lat", latitude);
  url.searchParams.set("lon", longitude);
  url.searchParams.set("appid", apiKey);
  url.searchParams.set("units", "metric");
  url.searchParams.set("lang", "en");

  const body = await fetchProviderJson(url, {
    provider: PROVIDERS.openWeather,
    errorMessage: "OpenWeather daily forecast failed",
    extractError: extractOpenWeatherError,
  });

  const items = Array.isArray(body.list) ? body.list : [];
  const timezoneOffset = readNumber(body.city?.timezone) ?? 0;
  const buckets = new Map();

  for (const item of items) {
    const date = isoDateFromUnixSeconds(item.dt, timezoneOffset);
    if (!isDateInRange(date, startDate, endDate)) {
      continue;
    }

    const bucket = getDailyBucket(buckets, date);
    addDailyTemperature(bucket, item.main);
    addDailyPrecipitation(bucket, item);
    addDailyWind(bucket, item.wind);
    addDailyCondition(bucket, firstWeather(item.weather), item.pop);
  }

  const forecast = [...buckets.values()]
    .sort((a, b) => a.date.localeCompare(b.date))
    .map(finalizeDailyBucket);

  if (forecast.length === 0) {
    throw new HttpError(
      502,
      "OpenWeather forecast did not include the requested date range.",
    );
  }

  return {
    latitude,
    longitude,
    startDate,
    endDate,
    timezone: timezoneOffsetLabel(timezoneOffset),
    units: "metric",
    message: "",
    daily: forecast,
  };
}

async function fetchMetNorwayCurrentWeather(latitude, longitude) {
  const body = await fetchMetNorway(latitude, longitude);
  const timeseries = readMetNorwayTimeseries(body);
  const current = timeseries[0];
  if (!current) {
    throw new HttpError(502, "MET Norway returned no current weather.");
  }

  const details = current.data?.instant?.details ?? {};
  const symbol = readMetNorwaySymbol(current);
  return {
    latitude,
    longitude,
    temperature: readNumber(details.air_temperature),
    feelsLike: null,
    condition: describeMetNorwaySymbol(symbol),
    conditionMain: metNorwaySymbolToGroup(symbol),
    iconCode: metNorwaySymbolToIcon(symbol),
    humidity: readNumber(details.relative_humidity),
    windSpeed: readNumber(details.wind_speed),
    pressure: readNumber(details.air_pressure_at_sea_level),
    observedAt: current.time ? String(current.time) : null,
    cityName: "",
    countryCode: "",
    timezone: "UTC",
    elevation: readNumber(body.geometry?.coordinates?.[2]),
    units: "metric",
  };
}

async function fetchMetNorwayDailyForecast(
  latitude,
  longitude,
  startDate,
  endDate,
) {
  const body = await fetchMetNorway(latitude, longitude);
  const timeseries = readMetNorwayTimeseries(body);
  const buckets = new Map();

  for (const item of timeseries) {
    const date = String(item.time ?? "").slice(0, 10);
    if (!isDateInRange(date, startDate, endDate)) {
      continue;
    }

    const bucket = getDailyBucket(buckets, date);
    addMetNorwayDailyTemperature(bucket, item);
    addMetNorwayDailyPrecipitation(bucket, item);
    addMetNorwayDailyWind(bucket, item);
    addMetNorwayDailyCondition(bucket, item);
  }

  const forecast = [...buckets.values()]
    .sort((a, b) => a.date.localeCompare(b.date))
    .map(finalizeDailyBucket);

  if (forecast.length === 0) {
    throw new HttpError(
      502,
      "MET Norway forecast did not include the requested date range.",
    );
  }

  return {
    latitude,
    longitude,
    startDate,
    endDate,
    timezone: "UTC",
    units: "metric",
    message: "",
    daily: forecast,
  };
}

async function fetchMetNorway(latitude, longitude) {
  const url = new URL(MET_NORWAY_URL);
  url.searchParams.set("lat", latitude);
  url.searchParams.set("lon", longitude);

  return fetchProviderJson(url, {
    provider: PROVIDERS.metNorway,
    errorMessage: "MET Norway weather failed",
    headers: {
      Accept: "application/json",
      "User-Agent": MET_NORWAY_USER_AGENT,
    },
    extractError: (_json, status) =>
      `MET Norway weather returned status ${status}.`,
  });
}

async function fetchProviderJson(
  url,
  { provider, errorMessage, headers = {}, extractError },
) {
  const response = await fetch(url, {
    headers: {
      Accept: "application/json",
      ...headers,
    },
    signal: AbortSignal.timeout(WEATHER_PROVIDER_TIMEOUT_MS),
  });
  const body = await response.json().catch(() => ({}));

  if (!response.ok) {
    throw new HttpError(
      response.status || 502,
      extractError ? extractError(body, response.status) : errorMessage,
    );
  }

  if (!body || typeof body !== "object") {
    throw new HttpError(502, `${provider} returned an invalid response.`);
  }

  return body;
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

function readOpenWeatherApiKey() {
  const apiKey = String(
    process.env.OPENWEATHER_API_KEY ??
      process.env.OPEN_WEATHER_API_KEY ??
      "",
  ).trim();
  if (!apiKey) {
    throw new HttpError(
      503,
      "OpenWeather API key is not configured. Set OPENWEATHER_API_KEY.",
    );
  }
  return apiKey;
}

function readNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function firstWeather(value) {
  return Array.isArray(value) && value.length > 0 ? value[0] : {};
}

function extractOpenWeatherError(body, status) {
  return typeof body.message === "string" && body.message.trim().length > 0
    ? body.message
    : `OpenWeather returned status ${status}.`;
}

function normalizeOpenWeatherDescription(weather) {
  const description = String(weather?.description ?? "").trim();
  if (description) {
    return titleCase(description);
  }
  const main = normalizeOpenWeatherMain(weather?.main);
  return main || "Unavailable";
}

function normalizeOpenWeatherMain(value) {
  const main = String(value ?? "").trim();
  if (!main) {
    return "";
  }
  if (main.toLowerCase() === "mist") {
    return "Clouds";
  }
  return titleCase(main);
}

function openWeatherIconToAppIcon(icon, main) {
  const normalizedIcon = String(icon ?? "").toLowerCase();
  if (normalizedIcon.startsWith("01")) {
    return "clear";
  }
  if (
    normalizedIcon.startsWith("02") ||
    normalizedIcon.startsWith("03") ||
    normalizedIcon.startsWith("04")
  ) {
    return "cloudy";
  }
  if (normalizedIcon.startsWith("09") || normalizedIcon.startsWith("10")) {
    return "rain";
  }
  if (normalizedIcon.startsWith("11")) {
    return "storm";
  }
  if (normalizedIcon.startsWith("13")) {
    return "snow";
  }
  if (normalizedIcon.startsWith("50")) {
    return "fog";
  }
  return weatherGroupToIcon(normalizeOpenWeatherMain(main));
}

function unixSecondsToIso(value) {
  const seconds = Number(value);
  return Number.isFinite(seconds) ? new Date(seconds * 1000).toISOString() : null;
}

function isoDateFromUnixSeconds(value, timezoneOffsetSeconds = 0) {
  const seconds = Number(value);
  const offset = Number(timezoneOffsetSeconds) || 0;
  if (!Number.isFinite(seconds)) {
    return "";
  }
  return new Date((seconds + offset) * 1000).toISOString().slice(0, 10);
}

function timezoneOffsetLabel(value) {
  const seconds = Number(value);
  if (!Number.isFinite(seconds)) {
    return "";
  }
  const sign = seconds < 0 ? "-" : "+";
  const absoluteSeconds = Math.abs(seconds);
  const hours = String(Math.floor(absoluteSeconds / 3600)).padStart(2, "0");
  const minutes = String(Math.floor((absoluteSeconds % 3600) / 60)).padStart(
    2,
    "0",
  );
  return `UTC${sign}${hours}:${minutes}`;
}

function isDateInRange(date, startDate, endDate) {
  return (
    /^\d{4}-\d{2}-\d{2}$/.test(date) &&
    date >= startDate &&
    date <= endDate
  );
}

function getDailyBucket(buckets, date) {
  if (!buckets.has(date)) {
    buckets.set(date, {
      date,
      temperatureMax: null,
      temperatureMin: null,
      apparentTemperatureMax: null,
      apparentTemperatureMin: null,
      precipitationSum: 0,
      hasPrecipitation: false,
      precipitationProbabilityMax: null,
      windSpeedMax: null,
      condition: "Unavailable",
      conditionMain: "",
      iconCode: "",
      conditionScore: -Infinity,
    });
  }
  return buckets.get(date);
}

function addDailyTemperature(bucket, main) {
  const temp = readNumber(main?.temp);
  const tempMin = readNumber(main?.temp_min) ?? temp;
  const tempMax = readNumber(main?.temp_max) ?? temp;
  const feelsLike = readNumber(main?.feels_like);

  bucket.temperatureMin = minNumber(bucket.temperatureMin, tempMin);
  bucket.temperatureMax = maxNumber(bucket.temperatureMax, tempMax);
  bucket.apparentTemperatureMin = minNumber(
    bucket.apparentTemperatureMin,
    feelsLike,
  );
  bucket.apparentTemperatureMax = maxNumber(
    bucket.apparentTemperatureMax,
    feelsLike,
  );
}

function addMetNorwayDailyTemperature(bucket, item) {
  const details = item.data?.instant?.details ?? {};
  const temperature = readNumber(details.air_temperature);
  bucket.temperatureMin = minNumber(bucket.temperatureMin, temperature);
  bucket.temperatureMax = maxNumber(bucket.temperatureMax, temperature);
}

function addDailyPrecipitation(bucket, item) {
  const probability = readNumber(item.pop);
  if (probability !== null) {
    bucket.precipitationProbabilityMax = maxNumber(
      bucket.precipitationProbabilityMax,
      Math.round(probability * 100),
    );
  }

  const rain = readNumber(item.rain?.["3h"]) ?? 0;
  const snow = readNumber(item.snow?.["3h"]) ?? 0;
  const precipitation = rain + snow;
  if (precipitation > 0) {
    bucket.precipitationSum += precipitation;
    bucket.hasPrecipitation = true;
  }
}

function addMetNorwayDailyPrecipitation(bucket, item) {
  const details = readMetNorwayForecastBlock(item)?.details ?? {};
  const precipitation = readNumber(details.precipitation_amount);
  if (precipitation !== null) {
    bucket.precipitationSum += precipitation;
    bucket.hasPrecipitation = true;
  }
}

function addDailyWind(bucket, wind) {
  bucket.windSpeedMax = maxNumber(bucket.windSpeedMax, readNumber(wind?.speed));
}

function addMetNorwayDailyWind(bucket, item) {
  const details = item.data?.instant?.details ?? {};
  bucket.windSpeedMax = maxNumber(
    bucket.windSpeedMax,
    readNumber(details.wind_speed),
  );
}

function addDailyCondition(bucket, weather, pop) {
  const conditionMain = normalizeOpenWeatherMain(weather?.main);
  const iconCode = openWeatherIconToAppIcon(weather?.icon, weather?.main);
  const score =
    weatherSeverityScore(conditionMain) * 100 +
    Math.round((Number(pop) || 0) * 100);

  if (score >= bucket.conditionScore) {
    bucket.condition = normalizeOpenWeatherDescription(weather);
    bucket.conditionMain = conditionMain;
    bucket.iconCode = iconCode;
    bucket.conditionScore = score;
  }
}

function addMetNorwayDailyCondition(bucket, item) {
  const symbol = readMetNorwaySymbol(item);
  const conditionMain = metNorwaySymbolToGroup(symbol);
  const score = weatherSeverityScore(conditionMain) * 100;

  if (score >= bucket.conditionScore) {
    bucket.condition = describeMetNorwaySymbol(symbol);
    bucket.conditionMain = conditionMain;
    bucket.iconCode = metNorwaySymbolToIcon(symbol);
    bucket.conditionScore = score;
  }
}

function finalizeDailyBucket(bucket) {
  return {
    date: bucket.date,
    condition: bucket.condition,
    conditionMain: bucket.conditionMain,
    iconCode: bucket.iconCode,
    temperatureMax: roundNumber(bucket.temperatureMax),
    temperatureMin: roundNumber(bucket.temperatureMin),
    apparentTemperatureMax: roundNumber(bucket.apparentTemperatureMax),
    apparentTemperatureMin: roundNumber(bucket.apparentTemperatureMin),
    precipitationSum: bucket.hasPrecipitation
      ? roundNumber(bucket.precipitationSum)
      : null,
    precipitationProbabilityMax: bucket.precipitationProbabilityMax,
    windSpeedMax: roundNumber(bucket.windSpeedMax),
  };
}

function minNumber(current, value) {
  if (value === null) {
    return current;
  }
  return current === null ? value : Math.min(current, value);
}

function maxNumber(current, value) {
  if (value === null) {
    return current;
  }
  return current === null ? value : Math.max(current, value);
}

function roundNumber(value) {
  if (value === null) {
    return null;
  }
  return Math.round(value * 10) / 10;
}

function readMetNorwayTimeseries(body) {
  const timeseries = body.properties?.timeseries;
  if (!Array.isArray(timeseries)) {
    throw new HttpError(502, "MET Norway returned no forecast timeseries.");
  }
  return timeseries;
}

function readMetNorwayForecastBlock(item) {
  return (
    item.data?.next_6_hours ??
    item.data?.next_1_hours ??
    item.data?.next_12_hours ??
    null
  );
}

function readMetNorwaySymbol(item) {
  return String(readMetNorwayForecastBlock(item)?.summary?.symbol_code ?? "");
}

function describeMetNorwaySymbol(symbol) {
  const normalized = normalizeMetNorwaySymbol(symbol);
  const description =
    MET_NORWAY_SYMBOL_DESCRIPTIONS[normalized] ||
    titleCase(normalized.replace(/_/g, " "));
  return description || "Unavailable";
}

function metNorwaySymbolToGroup(symbol) {
  const normalized = normalizeMetNorwaySymbol(symbol);
  if (normalized.includes("thunder")) {
    return "Thunderstorm";
  }
  if (normalized.includes("snow") || normalized.includes("sleet")) {
    return "Snow";
  }
  if (normalized.includes("rain")) {
    return "Rain";
  }
  if (normalized.includes("fog") || normalized.includes("cloud")) {
    return "Clouds";
  }
  if (normalized.includes("clear") || normalized.includes("fair")) {
    return "Clear";
  }
  return "";
}

function metNorwaySymbolToIcon(symbol) {
  return weatherGroupToIcon(metNorwaySymbolToGroup(symbol));
}

function normalizeMetNorwaySymbol(symbol) {
  return String(symbol ?? "")
    .toLowerCase()
    .replace(/_(day|night|polartwilight)$/u, "");
}

function weatherGroupToIcon(group) {
  const normalized = String(group ?? "").toLowerCase();
  if (normalized === "clear") {
    return "clear";
  }
  if (normalized === "clouds") {
    return "cloudy";
  }
  if (normalized === "rain" || normalized === "drizzle") {
    return "rain";
  }
  if (normalized === "snow") {
    return "snow";
  }
  if (normalized === "thunderstorm") {
    return "storm";
  }
  if (normalized === "mist" || normalized === "fog") {
    return "fog";
  }
  return "";
}

function weatherSeverityScore(group) {
  switch (String(group ?? "").toLowerCase()) {
    case "thunderstorm":
      return 6;
    case "snow":
      return 5;
    case "rain":
    case "drizzle":
      return 4;
    case "clouds":
    case "mist":
    case "fog":
      return 3;
    case "clear":
      return 1;
    default:
      return 0;
  }
}

function titleCase(value) {
  return String(value ?? "")
    .toLowerCase()
    .replace(/\b[a-z]/g, (match) => match.toUpperCase());
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

const MET_NORWAY_SYMBOL_DESCRIPTIONS = {
  clearsky: "Clear sky",
  fair: "Fair",
  partlycloudy: "Partly cloudy",
  cloudy: "Cloudy",
  lightrainshowers: "Light rain showers",
  rainshowers: "Rain showers",
  heavyrainshowers: "Heavy rain showers",
  lightrain: "Light rain",
  rain: "Rain",
  heavyrain: "Heavy rain",
  lightsnow: "Light snow",
  snow: "Snow",
  heavysnow: "Heavy snow",
  lightsleet: "Light sleet",
  sleet: "Sleet",
  heavysleet: "Heavy sleet",
  fog: "Fog",
  lightrainandthunder: "Light rain and thunder",
  rainandthunder: "Rain and thunder",
  heavyrainandthunder: "Heavy rain and thunder",
  lightsnowandthunder: "Light snow and thunder",
  snowandthunder: "Snow and thunder",
  heavysnowandthunder: "Heavy snow and thunder",
  lightsleetandthunder: "Light sleet and thunder",
  sleetandthunder: "Sleet and thunder",
  heavysleetandthunder: "Heavy sleet and thunder",
};

module.exports = {
  fetchCurrentWeather,
  fetchDailyForecast,
};
