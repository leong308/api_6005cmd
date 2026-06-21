# External API Aggregation Architecture

## 1. Purpose

The Smart Travel Planner backend acts as an **API aggregation layer** between the Flutter application and multiple external data providers. The Flutter application does not need to understand each provider's authentication method, URL structure, response format, rate limit, or failure behavior. Instead, it calls the project's own Express API under `/api` and receives stable, application-specific JSON.

The backend performs five main responsibilities:

1. Accept and validate a request from Flutter.
2. Load local trip and user data when the endpoint is trip-specific.
3. Read cached data before consuming an external provider.
4. Call one or more external APIs, apply fallback rules, and normalize their responses.
5. Combine the normalized data into one response owned by this project.

This is aggregation rather than a simple proxy because endpoints such as `GET /api/trips/:id/summary` and `GET /api/trips/:id/agenda` combine local database records with several external services and project-generated data.

## 2. High-level architecture

```text
Flutter application
       |
       | HTTPS + JWT bearer token
       v
Express routes and controllers
       |
       +--> Local trip/user repository
       |
       +--> Cache layer
       |      +--> MongoDB api_cache
       |      +--> In-memory service caches
       |      +--> Per-trip weather JSON files
       |
       +--> Provider services
              +--> Open-Meteo
              +--> OpenWeather
              +--> MET Norway
              +--> Foursquare Places
              +--> Geoapify Places and Reverse Geocoding
              +--> OpenStreetMap Nominatim
              +--> REST Countries
              +--> Google Routes
       |
       v
Normalized and aggregated project response
```

The API router is mounted at `/api`. Feature routers then expose `/trips`, `/external`, `/countries`, `/auth`, and `/health` endpoints.

## 3. Two aggregation entry styles

### 3.1 Direct external proxy endpoints

Endpoints under `/api/external` accept provider inputs directly, such as coordinates or a country name.

Examples:

- `GET /api/external/weather?lat=...&lng=...`
- `GET /api/external/weather/forecast?lat=...&lng=...&startDate=...&endDate=...`
- `GET /api/external/recommendations?lat=...&lng=...&preferences=food,culture`
- `GET /api/external/reverse-geocode?lat=...&lng=...`
- `GET /api/external/route?fromLat=...&fromLng=...&toLat=...&toLng=...&mode=walk`

These endpoints are useful when the caller already has the required coordinates. They still protect API keys, validate inputs, apply fallback behavior, and return the project's response shape.

### 3.2 Trip-aware project endpoints

Endpoints under `/api/trips/:id` first load the authenticated user's trip. Provider inputs are derived from the stored trip record instead of being supplied by the client.

For example, `GET /api/trips/:id/weather` performs the following:

1. Authenticate the JWT.
2. Load the trip by `id` and `ownerUserId`.
3. Read `latitude` and `longitude` from the trip.
4. Check the trip weather cache.
5. Call the weather provider chain when required.
6. Return weather together with provider and cache metadata.

This approach prevents the client from repeatedly sending the same destination data and ensures that users can only aggregate data for trips they own.

## 4. Main summary aggregation flow

The main aggregation endpoint is:

```http
GET /api/trips/:id/summary
Authorization: Bearer <jwt>
```

### Step 1: Route and authentication

The summary router applies `authMiddleware`. A valid user identity is therefore available as `req.user.id` before aggregation starts.

### Step 2: Parse aggregation options

The controller parses and constrains optional query parameters:

- `recommendationLimit`: allowed values are `3`, `5`, or `10`.
- `recommendationLimits`: per-preference limits such as `food:3,culture:5`.
- `availabilityDays`: number of days that use live opening-time lookups, from `0` to `7`.
- `routeMapDays`: number of agenda days for which route maps are generated, from `0` to `21`.
- `routeMapDayIndexes`: explicit zero-based agenda day indexes for route generation.
- `refresh` or `forceRefresh`: parsed as a boolean.

### Step 3: Load the local trip

The summary service loads the trip from the repository using both the trip ID and authenticated user ID. If no matching trip exists, the service throws a `404 Trip not found` error.

The trip record supplies the common aggregation context:

- Destination name and country
- Latitude and longitude
- Start and end dates
- User travel preferences
- Trip update timestamp

### Step 4: Check the summary cache

A stable cache key is built from:

- Trip ID
- `trip.updatedAt`
- Recommendation limits
- Availability-day settings
- Route-map settings
- Agenda cache version

The service checks the MongoDB `api_cache` collection under the `trip_summary` namespace. If a matching unexpired value exists, it returns the complete summary without calling providers again.

Including `trip.updatedAt` provides natural invalidation: editing the trip produces a different cache key, so old destination data is not reused for the modified trip.

### Step 5: Start independent provider work concurrently

The service starts these operations before awaiting them together with `Promise.all`:

1. Current weather for the trip.
2. Daily weather forecast for the trip dates.
3. Google Places-shaped demo data.
4. Recommendation groups for all selected preferences.
5. Country information.
6. Destination-country resolution when the trip has no stored country.

Concurrency reduces total response time. If weather takes 700 ms, recommendations take 900 ms, and country information takes 500 ms, the independent portion is approximately the slowest call rather than their sum.

### Step 6: Isolate partial failures

Each independent source has its own `try/catch`. One failed provider does not normally fail the whole summary.

Fallback values include:

- Current weather: `null`
- Forecast: a valid forecast object with `daily: []` and an explanatory message
- Google Places demo: `null`
- Recommendations: `[]`
- Country information: `null`
- Reverse-geocoded country: an empty string

This is called **graceful degradation**. The Flutter app still receives the trip and any modules that succeeded.

### Step 7: Build derived project data

The backend flattens grouped recommendations into a general `recommendations` array and then generates a trip agenda.

The agenda is project-owned data derived from:

- Trip dates
- Trip preferences
- Daily weather
- Recommendation groups
- Foursquare `open_at` availability queries
- Optional Google walking routes

The timed agenda follows a food/place pattern. If timed agenda generation fails, the service attempts a simpler agenda based on the already-fetched recommendation groups. If no usable provider recommendations exist, it returns an explicit insufficient-data result rather than inventing placeholder venues.

### Step 8: Assemble and cache the project response

The final summary shape is:

```json
{
  "trip": {},
  "weather": {},
  "dailyWeatherForecast": {},
  "googlePlaces": [],
  "recommendations": [],
  "recommendationGroups": [],
  "recommendationLimit": 5,
  "recommendationLimits": {},
  "countryInfo": {},
  "tripAgenda": {},
  "agenda": {}
}
```

The value is written to MongoDB under the `trip_summary` namespace and returned inside the standard HTTP envelope:

```json
{
  "success": true,
  "tripId": "<trip-id>",
  "data": {}
}
```

## 5. Provider-specific aggregation and fallback rules

### 5.1 Weather

The weather service tries providers in this order:

1. Open-Meteo
2. OpenWeather
3. MET Norway

The next provider is attempted when the previous provider fails, times out, is rate-limited, lacks configuration, or returns unusable data. If every provider fails, the service throws a `502` error containing the provider failure chain.

All three providers are mapped into the same project fields, including:

- `temperature`
- `feelsLike`
- `condition`
- `conditionMain`
- `iconCode`
- `humidity`
- `windSpeed`
- `pressure`
- `observedAt`
- `timezone`
- `units`

Forecast responses are similarly normalized into a `daily` array with consistent maximum/minimum temperature, precipitation, wind, condition, and icon fields.

Trip-aware weather adds another fallback level. If all live providers fail, a recently expired per-trip weather cache may be served with:

```json
{
  "cached": true,
  "stale": true,
  "warning": "Provider failed; serving stale cached weather..."
}
```

This stale response is only allowed within `TRIP_STALE_WEATHER_BACKUP_TTL_MS`.

### 5.2 Recommendations

Foursquare is the primary nearby-place provider. The service:

1. Converts a project preference such as `food`, `culture`, or `nature` into a Foursquare search query.
2. Sends destination coordinates, radius, result limit, and optional `open_at` time.
3. Requests only fields needed by the application.
4. Maps each Foursquare result into the project recommendation model.

If Foursquare is unavailable, misconfigured, rate-limited, times out, or returns no places, Geoapify Places is called automatically.

Geoapify results are mapped into the same recommendation fields, so routes, summaries, agendas, models, and UI widgets do not need provider-specific logic. The `source` and availability fields preserve enough metadata to explain whether opening hours were verified.

Multiple preferences are aggregated concurrently into groups:

```json
[
  {
    "preference": "food",
    "limit": 3,
    "recommendations": []
  },
  {
    "preference": "culture",
    "limit": 5,
    "recommendations": []
  }
]
```

### 5.3 Reverse geocoding

Coordinate-to-country lookup uses this chain:

1. Geoapify Reverse Geocoding
2. OpenStreetMap Nominatim
3. An `unavailable` normalized result

Geoapify results are cached using rounded coordinates to reduce paid API usage. Nominatim requests are rate-limited by the backend to at least 1.1 seconds between requests. When Nominatim returns a country code, REST Countries is used to normalize the country name into English.

### 5.4 Country information

REST Countries is called using an exact full-text name first. If the exact lookup fails, a partial-name lookup is attempted.

Its large provider response is reduced to:

- Country name
- Capital
- Currency name
- Languages
- Region
- Country code
- Flag URL

If both lookups fail, the service returns a normalized unavailable object containing `N/A` values and a warning. This keeps the own API schema stable even when the provider is unavailable.

### 5.5 Routes

The route service calls Google Routes with either `WALK` or `DRIVE`. The API key remains in the backend environment and is never exposed to Flutter.

The provider's encoded polyline is decoded into a project-friendly list:

```json
"path": [
  { "latitude": 1.3001, "longitude": 103.8001 },
  { "latitude": 1.3010, "longitude": 103.8010 }
]
```

Route responses also include normalized distance, duration, mode, origin, destination, and provider fields. Route results are cached in MongoDB using rounded origin/destination coordinates and travel mode.

Agenda route-map generation calls this route service for each pair of consecutive stops. Calls are concurrency-limited to avoid provider bursts. If Google Routes fails for a leg, the agenda still returns a straight-line preview with a Haversine distance estimate and estimated walking duration.

### 5.6 Google Places endpoint

The current Google Places endpoints do not call the live Google Places API. They return deterministic provider-shaped demo records. They should be described as stubs, not as live aggregation.

## 6. Normalization strategy

External providers use incompatible field names and structures. The services therefore act as **anti-corruption layers**: provider-specific details stop at the service boundary.

Examples:

- Open-Meteo `temperature_2m`, OpenWeather `main.temp`, and MET Norway `air_temperature` all become `temperature`.
- Foursquare and Geoapify coordinates both become `{ latitude, longitude }`.
- Different weather codes and symbols become common `conditionMain` and `iconCode` values.
- Google encoded route polylines become a decoded `path` array.
- REST Countries currencies and languages become simple project values.

The own API contract can therefore remain stable if a provider is replaced. Only the provider service and mapper should need to change.

## 7. Cache layers

The project uses three cache types.

### 7.1 MongoDB API cache

The `api_cache` collection stores reusable values by `namespace` and `key`. It is used for summaries, agendas, routes, recommendation results, trip-country data, and Geoapify reverse-country lookups. Optional expiry timestamps are enforced during reads.

When MongoDB is not configured, persistent cache reads return a miss and writes become no-ops.

### 7.2 In-memory service cache

Weather, Foursquare, Geoapify, reverse-geocoding, and agenda route-leg services use process-memory maps. These are fast but are cleared whenever the Node.js process restarts and are not shared between multiple backend instances.

### 7.3 Per-trip weather file cache

Current weather and forecast are stored separately in one JSON file per trip under `backend/.data/weather-cache`. Cache keys include coordinates, date range, and `trip.updatedAt`, so trip edits invalidate previous entries without a separate invalidation request.

## 8. Security boundary

The backend aggregation layer protects the system in several ways:

- Provider API keys remain in backend environment variables.
- Trip endpoints require JWT authentication.
- Repository lookups include `ownerUserId`, preventing cross-user trip access.
- Coordinates, dates, limits, and route modes are validated or constrained before provider calls.
- CORS is enforced centrally.
- Provider errors are converted into the project's JSON error envelope.
- Provider response sizes and fields are reduced before being sent to Flutter.

## 9. Error model

Validation and known provider/setup failures use `HttpError`. Errors passed to the final middleware are returned as JSON:

```json
{
  "success": false,
  "statusCode": 400,
  "message": "Query params lat and lng are required numbers."
}
```

There are two intended failure behaviors:

- **Fail the endpoint:** invalid inputs, missing trip, authentication failure, or complete failure of a direct provider endpoint.
- **Degrade one module:** the combined summary catches independent provider failures and returns partial data.

## 10. End-to-end example

For `GET /api/trips/123/summary?availabilityDays=1&routeMapDays=1`:

1. Flutter sends the JWT through `ApiClient`.
2. Express routes the request to the summary controller.
3. Authentication resolves the current user.
4. The controller validates aggregation options.
5. The summary service loads trip `123` for that user.
6. MongoDB is checked for the complete summary.
7. On a cache miss, weather, forecast, recommendations, country data, and demo places are requested concurrently.
8. Weather tries Open-Meteo, then OpenWeather, then MET Norway.
9. Recommendations try Foursquare, then Geoapify.
10. The agenda requests time-specific place availability for the configured days.
11. Google Routes generates walking legs for the configured route-map days; failed legs become straight-line estimates.
12. The backend assembles one normalized summary object.
13. The summary is cached and returned to Flutter.
14. Flutter converts the response into `TripSummaryModel`; it never parses raw provider payloads.

## 11. Current implementation notes

- `refresh`/`forceRefresh` is parsed by the summary controller, but `summaryService.generateSummary` currently checks and returns the summary cache without using that flag. It also does not pass the flag into weather or recommendation service calls. Therefore, refresh does not currently bypass the complete summary cache.
- Direct `/api/external/weather` and `/api/external/recommendations` routes do pass their refresh flag to the related service.
- Trip-specific weather routes currently do not parse a refresh query parameter; they rely on per-trip cache expiry and stale fallback behavior.
- The summary's Google Places data is obtained by making an HTTP request back to the backend's own `/api/external/google-places` endpoint. A direct service call would avoid this internal network hop if the stub is later replaced with a live implementation.
- Persistent cache entries without a supplied TTL remain until their key changes or they are explicitly deleted. Trip update timestamps reduce stale reuse but old cache documents may remain stored.

These notes describe the code's current behavior and should be updated when refresh propagation, live Google Places integration, or cache cleanup is implemented.
