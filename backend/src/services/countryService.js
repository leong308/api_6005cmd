/**
 * REST Countries service.
 *
 * This file calls the REST Countries API and maps its large response into the
 * smaller country detail shape used by the trip summary and country endpoints.
 */
const { HttpError } = require("../lib/http");

/**
 * Fetches country information from the REST Countries API.
 * @param {string} countryName - The name of the country.
 * @returns {Promise<object>} Parsed country details.
 */
async function fetchCountryData(countryName) {
  if (!countryName) {
    throw new HttpError(400, "Country name is required.");
  }

  const encodedName = encodeURIComponent(countryName.trim());
  const fullTextUrl = `https://restcountries.com/v3.1/name/${encodedName}?fullText=true`;
  const partialUrl = `https://restcountries.com/v3.1/name/${encodedName}`;

  const fullTextCountry = await fetchRestCountry(fullTextUrl).catch((error) => {
    console.warn(`Country full-text lookup failed for ${countryName}: ${error.message}`);
    return null;
  });
  if (fullTextCountry) {
    return mapRestCountry(fullTextCountry, countryName);
  }

  const partialCountry = await fetchRestCountry(partialUrl).catch((error) => {
    console.warn(`Country details fallback used for ${countryName}: ${error.message}`);
    return null;
  });
  if (partialCountry) {
    return mapRestCountry(partialCountry, countryName);
  }

  return buildUnavailableCountryData(countryName);
}

async function fetchCountryDataByCode(countryCode) {
  const normalizedCode = String(countryCode ?? "").trim().toUpperCase();
  if (!/^[A-Z]{2,3}$/.test(normalizedCode)) {
    throw new HttpError(400, "Country code is required.");
  }

  const url = `https://restcountries.com/v3.1/alpha/${encodeURIComponent(normalizedCode)}`;

  try {
    const response = await fetch(url);
    if (!response.ok) {
      if (response.status === 404) {
        throw new HttpError(404, `Country code '${normalizedCode}' not found.`);
      }
      throw new HttpError(
        response.status,
        "External API error: Failed to fetch country data.",
      );
    }

    const data = await response.json();
    if (!Array.isArray(data) || data.length === 0) {
      throw new HttpError(404, `Country code '${normalizedCode}' not found.`);
    }

    return mapRestCountry(data[0], normalizedCode);
  } catch (error) {
    if (error instanceof HttpError) {
      throw error;
    }
    throw new HttpError(500, `Failed to fetch country data: ${error.message}`);
  }
}

async function fetchCountryNameByCode(countryCode) {
  const country = await fetchCountryDataByCode(countryCode);
  return country.country;
}

function mapRestCountry(country, fallbackName) {
  // Extract currency name
  let currencyName = "N/A";
  if (country.currencies) {
    const keys = Object.keys(country.currencies);
    if (keys.length > 0) {
      currencyName = country.currencies[keys[0]].name || "N/A";
    }
  }

  // Extract languages
  const languages = country.languages ? Object.values(country.languages) : [];

  // Extract flag image URL (prefer png, fallback to svg or empty string)
  const flagUrl = country.flags ? (country.flags.png || country.flags.svg || "") : "";

  return {
    country: country.name?.common || fallbackName,
    capital: Array.isArray(country.capital) && country.capital.length > 0 ? country.capital[0] : "N/A",
    currency: currencyName,
    languages: languages,
    region: country.region || "N/A",
    countryCode: country.cca2 || country.cca3 || "N/A",
    flag: flagUrl,
  };
}

async function fetchRestCountry(url) {
  const response = await fetch(url);
  if (!response.ok) {
    if (response.status === 404) {
      throw new HttpError(404, "Country not found.");
    }
    throw new HttpError(
      response.status,
      "External API error: Failed to fetch country data.",
    );
  }

  const data = await response.json();
  if (!Array.isArray(data) || data.length === 0) {
    throw new HttpError(404, "Country not found.");
  }
  return data[0];
}

function buildUnavailableCountryData(countryName) {
  return {
    country: String(countryName).trim(),
    capital: "N/A",
    currency: "N/A",
    languages: [],
    region: "N/A",
    countryCode: "N/A",
    flag: "",
    warning: "Country detail provider is unavailable.",
  };
}

module.exports = {
  fetchCountryData,
  fetchCountryDataByCode,
  fetchCountryNameByCode,
};
