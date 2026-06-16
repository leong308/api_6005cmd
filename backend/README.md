# Smart Travel Planner Backend

This directory contains the Express.js backend and the application's own API.
It is responsible for authentication, trip ownership, persistence, external API
aggregation, caching, response normalization, and error handling.

## Runtime Request Flow

```text
npm start / npm run dev
        |
        v
src/server.js
  Creates the app, installs final 404/error handlers, and listens on PORT
        |
        v
src/app.js
  Configures CORS and body parsing, then mounts /api
        |
        v
src/routes/index.js
  Dispatches requests to health, auth, trips, external, and countries routers
        |
        v
Controllers and route handlers
        |
        +-- Repository: users, trips, cache
        +-- Services: JWT, weather, places, routes, agenda, country lookup
        `-- External providers
```

Local API base URL:

```text
http://localhost:3000/api
```

## Requirements

- Node.js 20 or newer. Node 20 provides the built-in `fetch` and
  `AbortSignal.timeout` APIs used by provider services.
- npm.
- MongoDB for persistent deployed storage.
- A Flutter client or HTTP tool such as Postman for exercising the API.

## Installation

```bash
cd backend
npm install
```

Create `backend/.env` for local configuration. The file is loaded automatically
by `src/config/env.js` and is ignored by Git.

Run with automatic restart:

```bash
npm run dev
```

Run without watch mode:

```bash
npm start
```

Verify the service:

```http
GET http://localhost:3000/api/health
```

Example response:

```json
{
  "success": true,
  "service": "smart-travel-planner-backend",
  "timestamp": "2026-06-15T00:00:00.000Z"
}
```

## Configuration Levels

The backend does not require every integration to be configured before it can
start.

### Minimum local development

No `.env` file is required. The backend uses:

- Port `3000`.
- Local development storage under `backend/.data`.
- A temporary JWT secret generated at runtime.
- Free providers where configuration is not required.

This mode is useful for initial UI work, but users and JWTs should be considered
temporary.

### Recommended local development

```env
PORT=3000
CORS_ORIGIN=http://localhost:5173

MONGO_URI=mongodb+srv://<username>:<password>@<cluster>/smart_travel_planner?retryWrites=true&w=majority
MONGO_DB_NAME=smart_travel_planner

JWT_SECRET=<at-least-32-random-characters>
JWT_EXPIRES_IN=7d

PUBLIC_API_BASE_URL=http://localhost:3000
PUBLIC_APP_BASE_URL=http://localhost:5173

EMAIL_PROVIDER=firebase
FIREBASE_AUTH_API_KEY=<firebase-web-api-key>

GEOAPIFY_API_KEY=<geoapify-key>
FOURSQUARE_API_KEY=<foursquare-key>
OPENWEATHER_API_KEY=<openweather-key>
GOOGLE_ROUTES_API_KEY=<google-routes-key>

NOMINATIM_USER_AGENT=SmartTripPlanner/1.0 (your-email@example.com)
MET_NORWAY_USER_AGENT=SmartTripPlanner/1.0 (your-email@example.com)
```

Generate a suitable JWT secret:

```bash
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```

## Environment Variable Reference

### Server and database

| Variable | Required | Default | Purpose |
| --- | --- | --- | --- |
| `PORT` | No | `3000` | HTTP listening port. Deployment platforms may supply it. |
| `CORS_ORIGIN` | Recommended | Allow all | Comma-separated permitted web origins. Localhost origins are also allowed for development. |
| `MONGO_URI` | Production | None | MongoDB connection string. Missing value enables local fallback storage. |
| `MONGO_DB_NAME` | No | Derived/default database | MongoDB database name. |
| `MONGO_SERVER_SELECTION_TIMEOUT_MS` | No | Driver/service default | MongoDB connection timeout override. |
| `PUBLIC_API_BASE_URL` | Recommended | Current request host | Base URL used to build verification and password-reset links. Do not include `/api`. |
| `PUBLIC_APP_BASE_URL` | Recommended | None | Public Flutter application URL used by email-related flows. |

### JWT and account lifecycle

| Variable | Required | Default | Purpose |
| --- | --- | --- | --- |
| `JWT_SECRET` | Production | Temporary development secret | Signs and verifies JWTs. Must be at least 32 characters and not a placeholder. |
| `JWT_EXPIRES_IN` | No | `7d` | JWT lifetime accepted by `jsonwebtoken`. |
| `JWT_ISSUER` | No | None | Optional issuer claim enforced during signing and verification. |
| `JWT_AUDIENCE` | No | None | Optional audience claim enforced during signing and verification. |
| `EMAIL_VERIFICATION_EXPIRES_IN_MS` | No | `7200000` | Non-Firebase verification-token lifetime. |
| `PASSWORD_RESET_EXPIRES_IN_MS` | No | `7200000` | Password-reset-token lifetime. |
| `UNVERIFIED_ACCOUNT_CLEANUP_INTERVAL_MS` | No | `600000` | Cleanup interval for expired unverified users. |

### Email delivery

`EMAIL_PROVIDER=firebase` is the recommended deployment configuration because
Firebase sends email actions over HTTPS.

| Variable | Required | Purpose |
| --- | --- | --- |
| `EMAIL_PROVIDER` | No | `firebase`, `resend`, `smtp`, or automatic provider selection. |
| `FIREBASE_AUTH_API_KEY` | For Firebase | Firebase project's Web API key. Email/Password authentication must be enabled. |
| `FIREBASE_AUTH_REQUEST_TIMEOUT_MS` | No | Firebase Identity Toolkit request timeout. |
| `RESEND_API_KEY` | For Resend | Resend API key. A verified sender domain is required for arbitrary recipients. |
| `RESEND_API_URL` | No | Resend endpoint override. |
| `MAIL_FROM` | For Resend/SMTP | Sender address. |
| `SMTP_HOST`, `SMTP_PORT` | For SMTP | SMTP server configuration. |
| `SMTP_USER`, `SMTP_PASS` | For SMTP | SMTP credentials. |
| `SMTP_SECURE` | No | Enables implicit TLS when `true`. |
| `SMTP_TLS_REJECT_UNAUTHORIZED` | No | Controls SMTP certificate validation. Keep enabled in production. |
| `EMAIL_DEV_FALLBACK_ON_ERROR` | No | Allows development verification/reset URLs when delivery fails. |

SMTP should not be used on Render Free because outbound SMTP ports are commonly
blocked.

### External providers

| Variable | Required | Purpose |
| --- | --- | --- |
| `GEOAPIFY_API_KEY` | For Geoapify | Reverse geocoding and Foursquare recommendation fallback. |
| `FOURSQUARE_API_KEY` | For live recommendations | Primary nearby-place provider. |
| `OPENWEATHER_API_KEY` | For weather fallback | Second weather provider after Open-Meteo. `OPEN_WEATHER_API_KEY` is also accepted. |
| `GOOGLE_ROUTES_API_KEY` | For routes | Google Routes API key. Google Maps/Places key variables are accepted as fallback key names. |
| `NOMINATIM_USER_AGENT` | Recommended | Descriptive identification required for responsible Nominatim use. |
| `MET_NORWAY_USER_AGENT` | Recommended | Descriptive identification for MET Norway requests. |

Optional provider tuning variables include:

```env
WEATHER_PROVIDER_TIMEOUT_MS=12000
FOURSQUARE_TIMEOUT_MS=10000
FOURSQUARE_AUTH_SCHEME=bearer
FOURSQUARE_PLACES_API_VERSION=2025-02-05
GEOAPIFY_TIMEOUT_MS=12000
GEOAPIFY_RADIUS_METERS=8000
GEOAPIFY_COUNTRY_CACHE_PRECISION=3
GOOGLE_ROUTES_TIMEOUT_MS=12000
RECOMMENDATION_EMPTY_CACHE_TTL_MS=900000
```

Provider URL variables also exist for controlled testing, but normal deployments
should use the built-in URLs.

### Trip weather cache

```env
TRIP_CURRENT_WEATHER_CACHE_TTL_MS=1800000
TRIP_DAILY_FORECAST_CACHE_TTL_MS=21600000
TRIP_STALE_WEATHER_BACKUP_TTL_MS=86400000
TRIP_WEATHER_CACHE_DIR=<optional-custom-directory>
```

## Authentication and JWT

### Registration and verification

`POST /api/auth/register` requires:

```json
{
  "name": "Example User",
  "email": "user@example.com",
  "password": "example-password"
}
```

Passwords are hashed with bcrypt before storage. Login is blocked until email
verification succeeds.

### Login

```http
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "example-password"
}
```

Successful login returns a JWT:

```json
{
  "success": true,
  "message": "Login successful.",
  "token": "<signed-jwt>",
  "data": {
    "id": "<user-id>",
    "name": "Example User",
    "email": "user@example.com",
    "emailVerified": true,
    "firstLogin": true
  }
}
```

### Protected requests

```http
Authorization: Bearer <signed-jwt>
```

`authMiddleware` verifies:

- The Bearer header exists and is correctly formed.
- The token signature matches `JWT_SECRET`.
- The algorithm is `HS256`.
- The token has not expired.
- Optional issuer and audience claims match configuration.

The decoded `{ id, email }` payload is assigned to `req.user`. Trip queries then
use `req.user.id` as `ownerUserId`, which enforces per-user data isolation.

JWTs are signed, not encrypted. Do not add passwords, provider keys, or other
secrets to the payload.

## Trip Data Model

Creating a trip requires:

```json
{
  "destinationName": "Tokyo",
  "destinationCountry": "Japan",
  "latitude": 35.6762,
  "longitude": 139.6503,
  "startDate": "2026-07-01",
  "endDate": "2026-07-05",
  "preferences": ["food", "culture"],
  "travelNotes": "Visit museums and local restaurants."
}
```

Required fields are `destinationName`, `destinationCountry`, `latitude`,
`longitude`, `startDate`, and `endDate`. The backend adds `id`, `ownerUserId`,
`createdAt`, and `updatedAt`.

## Endpoint Reference

### System

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| `GET` | `/` | No | Root process status and `/api` discovery response. |
| `GET` | `/api/health` | No | Lightweight process health check. |

### Authentication

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| `POST` | `/api/auth/register` | No | Register and send email verification. |
| `GET` | `/api/auth/verify-email?token=...` | No | Verify a non-Firebase email token. |
| `POST` | `/api/auth/resend-verification` | No | Send a new verification request. |
| `POST` | `/api/auth/forgot-password` | No | Send a password-reset request. |
| `GET` | `/api/auth/reset-password?token=...` | No | Display the backend-hosted reset form. |
| `POST` | `/api/auth/reset-password` | No | Apply a reset token and new password. |
| `POST` | `/api/auth/login` | No | Validate credentials and return JWT. |
| `GET` | `/api/auth/profile` | JWT | Return the current user's profile. |
| `POST` | `/api/auth/complete-tour` | JWT | Set `firstLogin` to `false`. |

### Trip CRUD

Every trip endpoint requires JWT authentication.

| Method | Path | Description |
| --- | --- | --- |
| `GET` | `/api/trips` | List trips owned by the current user. |
| `POST` | `/api/trips` | Create a trip owned by the current user. |
| `GET` | `/api/trips/:id` | Get one owned trip. |
| `PUT` | `/api/trips/:id` | Update one owned trip and invalidate related cache. |
| `DELETE` | `/api/trips/:id` | Delete one owned trip and its weather cache. |

### Trip aggregation modules

| Method | Path | Description |
| --- | --- | --- |
| `GET` | `/api/trips/:id/weather` | Current weather using the provider fallback chain and trip file cache. |
| `GET` | `/api/trips/:id/weather/forecast` | Forecast for the trip date range. |
| `GET` | `/api/trips/:id/google-places` | Stored/provider-shaped Google Places demo data. |
| `GET` | `/api/trips/:id/recommendations` | Preference-grouped Foursquare results with Geoapify fallback. |
| `GET` | `/api/trips/:id/agenda` | Generated weather-aware, timed agenda. |
| `GET` | `/api/trips/:id/country-info` | Destination country details. |
| `GET` | `/api/trips/:id/summary` | Combined trip, weather, places, country, recommendation, and agenda response. |

Recommendation and agenda query parameters:

| Parameter | Example | Meaning |
| --- | --- | --- |
| `limit` or `recommendationLimit` | `5` | Default per-preference result count. Accepted UI values are `3`, `5`, and `10`. |
| `recommendationLimits` | `food:3,culture:5` | Per-preference result limits. |
| `availabilityDays` | `1` | Agenda days using live time-specific place availability, clamped to `0..7`. |
| `routeMapDays` | `2` | First agenda days with generated route maps, clamped to `0..21`. |
| `routeMapDayIndexes` | `0,3` | Explicit zero-based agenda days for route generation. |

Summary example:

```http
GET /api/trips/<trip-id>/summary?recommendationLimits=food:3,culture:5&availabilityDays=1&routeMapDays=1
Authorization: Bearer <jwt>
```

### Direct external proxy endpoints

These endpoints do not load a stored trip. The caller supplies provider inputs
directly.

| Method | Path | Required query parameters |
| --- | --- | --- |
| `GET` | `/api/external/weather` | `lat`, `lng`; optional `refresh=true` |
| `GET` | `/api/external/weather/forecast` | `lat`, `lng`, `startDate`, `endDate`; optional `refresh=true` |
| `GET` | `/api/external/recommendations` | `lat`, `lng`; optional `preference`, `preferences`, `limit`, `recommendationLimits`, `refresh` |
| `GET` | `/api/external/reverse-geocode` | `lat`, `lng` |
| `GET` | `/api/external/country-info` | `country` |
| `GET` | `/api/external/route` | `fromLat`, `fromLng`, `toLat`, `toLng`; optional `mode=walk|car|vehicle` |
| `GET` | `/api/external/walking-route` | Alias of the route handler. |
| `GET` | `/api/external/google-places` | `lat`, `lng`; optional `preference` — currently demo data. |
| `GET` | `/api/countries/:name` | Country name in the URL path. |

## Aggregation and Provider Fallback

The combined summary endpoint loads the local trip and checks the summary cache.
On a cache miss, independent modules are requested concurrently. Each module has
isolated error handling so partial data can still be returned.

### Weather

```text
Open-Meteo -> OpenWeather -> MET Norway -> stale trip cache when eligible
```

All providers are converted to common current-weather and daily-forecast
models. A total live-provider failure returns `502` for direct endpoints. A
combined summary instead degrades the weather module.

### Recommendations

```text
Foursquare Places -> Geoapify Places -> empty recommendation group
```

Both providers are mapped into the same recommendation model. Agenda generation
uses the same service with optional Foursquare `open_at` filters.

### Reverse geocoding

```text
Geoapify Reverse Geocoding -> Nominatim -> normalized unavailable response
```

Nominatim calls are rate-limited in process. REST Countries may be used to
convert returned country codes into an English country name.

### Country information

```text
REST Countries full-name lookup -> partial-name lookup -> N/A response
```

### Routes

Google Routes returns walking or driving distance, duration, and an encoded
polyline. The backend decodes the polyline into `{ latitude, longitude }` points.
When an agenda route leg fails, a straight-line preview and estimated walking
duration are returned instead.

For implementation-level detail, see `API_AGGREGATION.md`.

## Response and Error Format

Successful endpoints use a JSON object beginning with:

```json
{
  "success": true,
  "data": {}
}
```

Some endpoints add fields such as `message`, `total`, `tripId`, `provider`,
`cached`, `stale`, or `warning`.

Known errors are returned through the centralized error middleware:

```json
{
  "success": false,
  "statusCode": 401,
  "message": "Invalid token."
}
```

Common status codes:

- `400`: invalid or missing request fields.
- `401`: missing, invalid, or expired JWT.
- `403`: email verification is required.
- `404`: route, trip, user, or requested record not found.
- `409`: duplicate email registration.
- `502`: all providers for a direct external operation failed.
- `503`: required provider key or production JWT configuration is missing.
- `500`: unexpected backend error.

## Persistence and Cache

### MongoDB mode

When `MONGO_URI` is present, the backend uses:

- `users`: account profile, password hash, verification/reset state, and
  `firstLogin`.
- `trips`: trip records with `ownerUserId`.
- `api_cache`: namespaced aggregation and provider cache records.

### Local development mode

Without MongoDB, development data is stored under `backend/.data`. This mode is
not suitable for production or horizontally scaled deployment.

### Cache layers

1. MongoDB cache for summaries, agendas, routes, recommendations, country data,
   and reverse-country lookups.
2. In-memory maps for fast repeated calls during the current Node process.
3. Per-trip weather files under `backend/.data/weather-cache`.

Trip cache keys include `trip.updatedAt`, coordinates, dates, and aggregation
options. Updating a trip therefore changes the relevant cache key. Repository
updates and deletes also invalidate matching cache namespaces.

## Render Deployment

Create a Node web service with:

```text
Root directory: backend
Build command: npm install
Start command: npm start
```

Recommended environment values:

```env
CORS_ORIGIN=https://smart-trip-planner.web.app
PUBLIC_API_BASE_URL=https://six005cmd-api.onrender.com
PUBLIC_APP_BASE_URL=https://smart-trip-planner.web.app

MONGO_URI=<production-mongodb-uri>
MONGO_DB_NAME=smart_travel_planner

JWT_SECRET=<64-byte-random-hex-secret>
JWT_EXPIRES_IN=7d

EMAIL_PROVIDER=firebase
FIREBASE_AUTH_API_KEY=<firebase-web-api-key>

GEOAPIFY_API_KEY=<geoapify-key>
FOURSQUARE_API_KEY=<foursquare-key>
OPENWEATHER_API_KEY=<openweather-key>
GOOGLE_ROUTES_API_KEY=<google-routes-key>

NOMINATIM_USER_AGENT=SmartTripPlanner/1.0 (your-email@example.com)
MET_NORWAY_USER_AGENT=SmartTripPlanner/1.0 (your-email@example.com)
```

Render supplies `PORT`; do not set it manually. Do not use
`NODE_ENV=development` in production. Firebase email delivery is preferred over
SMTP on Render Free.

## Testing

No backend unit-test script is currently defined in `package.json`.

Use the Postman collection from the repository root:

```text
postman/SmartTravelPlanner.postman_collection.json
```

For a basic manual check:

1. Start the backend.
2. Call `/api/health`.
3. Register and verify a user.
4. Log in and copy the returned JWT.
5. Set `Authorization: Bearer <jwt>` in Postman.
6. Create a trip.
7. Call the trip summary and module endpoints.

## Troubleshooting

### `401 Access denied. No token provided.`

Add `Authorization: Bearer <jwt>` to protected requests.

### Token becomes invalid after backend restart

Set a persistent `JWT_SECRET` in `backend/.env`. Without one, development uses a
new temporary secret after every process restart.

### `403 Please verify your email before logging in.`

Complete the verification email flow or configure Firebase Email/Password and a
valid `FIREBASE_AUTH_API_KEY`.

### Flutter cannot reach the backend

- Confirm `GET http://localhost:3000/api/health` works.
- Check `SELF_API_BASE_URL` includes `/api`.
- Check `CORS_ORIGIN` includes the Flutter web origin.
- Localhost, `127.0.0.1`, and `::1` origins are automatically allowed in local
  development.

### Recommendations are empty

Configure `FOURSQUARE_API_KEY` and `GEOAPIFY_API_KEY`. If both providers fail,
the service intentionally returns an empty list instead of invented venues.

### Route maps use straight lines

Configure and enable the Google Routes API with `GOOGLE_ROUTES_API_KEY`.
Straight-line legs are the expected fallback when Google does not return a
routable walking path.

## Current Implementation Notes

- Google Places endpoints are provider-shaped stubs with deterministic data.
- `refresh=true` works for direct external weather and recommendation routes.
- The summary controller parses refresh, but the current summary service does
  not bypass the complete summary cache or propagate refresh to providers.
- Trip weather endpoints do not currently consume a refresh parameter.
- Some persistent cache entries have no TTL and remain until invalidated or
  replaced by a different key.
- The summary service currently calls the backend's own Google Places stub over
  HTTP instead of invoking a local service function.

These constraints are also documented in `API_AGGREGATION.md` and should be
updated when the implementation changes.
