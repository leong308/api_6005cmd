# Smart Travel Planner

Smart Travel Planner is a full-stack travel planning application built with a
Flutter client and an Express.js API. Users can create trips, select a
destination from a map, receive weather and place information, generate a
weather-aware agenda, and view walking routes for agenda stops.

The Express backend is the application's **own API**. It stores application
data, authenticates users, protects trip ownership, calls external providers,
normalizes their different response formats, applies caching and fallback
rules, and returns one stable JSON contract to Flutter.

## System Overview

```text
Flutter application
        |
        | HTTP/JSON + JWT bearer token
        v
Express API: http://localhost:3000/api
        |
        +-- MongoDB or local development storage
        +-- API and weather caches
        +-- External provider adapters
                +-- Open-Meteo / OpenWeather / MET Norway
                +-- Foursquare / Geoapify Places
                +-- Geoapify / Nominatim reverse geocoding
                +-- REST Countries
                +-- Google Routes
```

## Main Features

- Account registration, email verification, login, password reset, and JWT
  authentication.
- Per-user trip creation, listing, editing, and deletion.
- Map-based destination selection and country detection.
- Current weather and daily forecasts with provider fallback.
- Nearby recommendations grouped by travel preference.
- Country information such as capital, currency, languages, region, and flag.
- Timed food/place agendas based on trip dates, weather, preferences, and
  available provider data.
- Optional walking route maps for agenda days.
- A combined trip summary endpoint that aggregates local and external data.
- An API demonstration screen and Postman collection for endpoint testing.

## Technology Stack

| Layer | Technology |
| --- | --- |
| Client | Flutter, Dart, Material UI |
| HTTP client | Dart `http` package |
| Maps | MapLibre |
| Backend | Node.js 20+, Express.js |
| Authentication | bcrypt password hashing, JWT, email verification |
| Database | MongoDB with local JSON fallback for development |
| Web hosting | Firebase Hosting configuration |
| Backend deployment | Render-compatible Express service |

## Repository Structure

```text
api_6005cmd/
|-- lib/                         Flutter application
|   |-- core/api/                API URL, client, and endpoint contracts
|   |-- features/                Auth, trips, summary, navigation, API demo
|   `-- shared/                  Shared views and utilities
|-- backend/
|   |-- src/server.js            Backend process entry point
|   |-- src/app.js               Express application and /api mount
|   |-- src/routes/              Own API endpoint definitions
|   |-- src/controllers/         Request/response controllers
|   |-- src/services/            Auth, aggregation, and provider adapters
|   |-- src/data/                Trip, user, and cache repositories
|   `-- API_AGGREGATION.md        Detailed aggregation architecture
|-- postman/                     Postman API collection
|-- test/                        Flutter tests
|-- firebase.json                Firebase Hosting configuration
`-- pubspec.yaml                 Flutter dependencies and metadata
```

The app renders Mapbox Streets, Outdoors, and Light vector styles through the
cross-platform map widget, including pitched 3D building extrusions on web and
mobile.

## API Starting Point

The backend process starts in `backend/src/server.js`. It creates the Express
application from `backend/src/app.js` and listens on `PORT`, or port `3000` by
default.

`backend/src/app.js` mounts the API router at `/api`, making the local base URL:

```text
http://localhost:3000/api
```

The route registry is `backend/src/routes/index.js`:

```text
/api/health       Service health check
/api/auth         Registration, verification, login, and profile
/api/trips        Protected trip and aggregation endpoints
/api/external     Direct external-provider proxy endpoints
/api/countries    Country lookup endpoint
```

## Prerequisites

- Flutter SDK compatible with Dart `^3.9.2`.
- Node.js `20` or newer.
- npm.
- MongoDB for persistent users, trips, and API cache in deployed environments.
- Provider keys only for the optional live integrations you intend to use.

## Quick Start

### 1. Start the backend

```bash
cd backend
npm install
npm run dev
```

Confirm that it is running:

```text
http://localhost:3000/api/health
```

The backend can start locally without MongoDB or provider keys. In that mode:

- Trip and user data use local development storage.
- Some integrations use free providers or fallbacks.
- Features requiring a missing API key may return unavailable data.
- A temporary JWT secret is generated and tokens become invalid after restart.

For persistent authentication and full provider support, configure
`backend/.env` as described in `backend/README.md`.

### 2. Start Flutter

From the repository root:

```bash
flutter pub get
flutter run -d chrome
```

Flutter uses this backend URL by default:

```dart
http://localhost:3000/api
```

To override the API URL:

```bash
flutter run -d chrome \
  --dart-define=SELF_API_BASE_URL=http://localhost:3000/api \
  --dart-define=EXTERNAL_PROXY_BASE_URL=http://localhost:3000/api/external
```

On PowerShell, the command can be entered on one line or split using the
PowerShell backtick instead of `\`.

## Authentication Flow

1. Flutter calls `POST /api/auth/register` with `name`, `email`, and `password`.
2. The backend hashes the password with bcrypt and sends an email verification
   request using the configured email provider.
3. The user verifies the email address.
4. Flutter calls `POST /api/auth/login`.
5. The backend returns a signed JWT containing the user ID and email.
6. Flutter stores the token in `ApiClient` and sends it with protected calls:

```http
Authorization: Bearer <jwt>
```

7. `authMiddleware` verifies the signature and expiration and exposes the user
   as `req.user`.
8. Trip repository queries filter by `ownerUserId`, preventing one user from
   reading or modifying another user's trips.

The default token lifetime is seven days. Production deployments must set a
strong `JWT_SECRET` of at least 32 characters.

## External API Aggregation

Flutter communicates with the project's Express API rather than calling most
providers directly. The backend:

1. Validates request inputs.
2. Loads the authenticated trip when required.
3. Checks persistent, memory, or file cache.
4. Calls the primary external provider.
5. Tries a fallback provider when supported.
6. Converts provider-specific fields into project models.
7. Combines the results into a stable response.

The primary combined endpoint is:

```http
GET /api/trips/:id/summary
Authorization: Bearer <jwt>
```

It aggregates the stored trip, current weather, forecast, recommendations,
country details, agenda, and optional route-map data. Independent provider calls
run concurrently and are isolated so that one provider failure does not usually
remove the entire summary.

Provider order:

| Capability | Primary | Fallback |
| --- | --- | --- |
| Current weather and forecast | Open-Meteo | OpenWeather, then MET Norway |
| Recommendations | Foursquare | Geoapify Places |
| Reverse geocoding | Geoapify | OpenStreetMap Nominatim |
| Country details | REST Countries exact lookup | Partial lookup, then unavailable object |
| Walking/driving routes | Google Routes | Straight-line estimate inside agenda route maps |

The Google Places endpoints currently return deterministic demo data and do not
call the live Google Places API.

See `backend/API_AGGREGATION.md` for the complete request lifecycle, normalized
models, cache strategy, fallback behavior, and current implementation notes.

## API Groups

### Public system and lookup endpoints

- `GET /api/health`
- `GET /api/countries/:name`
- `GET /api/external/weather`
- `GET /api/external/weather/forecast`
- `GET /api/external/google-places`
- `GET /api/external/recommendations`
- `GET /api/external/reverse-geocode`
- `GET /api/external/country-info`
- `GET /api/external/route`
- `GET /api/external/walking-route`

### Authentication endpoints

- `POST /api/auth/register`
- `GET /api/auth/verify-email`
- `POST /api/auth/resend-verification`
- `POST /api/auth/forgot-password`
- `GET /api/auth/reset-password`
- `POST /api/auth/reset-password`
- `POST /api/auth/login`
- `GET /api/auth/profile` — JWT required
- `POST /api/auth/complete-tour` — JWT required

### Protected trip endpoints

- `GET /api/trips`
- `POST /api/trips`
- `GET /api/trips/:id`
- `PUT /api/trips/:id`
- `DELETE /api/trips/:id`
- `GET /api/trips/:id/weather`
- `GET /api/trips/:id/weather/forecast`
- `GET /api/trips/:id/google-places`
- `GET /api/trips/:id/recommendations`
- `GET /api/trips/:id/agenda`
- `GET /api/trips/:id/country-info`
- `GET /api/trips/:id/summary`

All `/api/trips/*` requests require `Authorization: Bearer <jwt>`.

The full endpoint reference, query parameters, request examples, and environment
variables are documented in `backend/README.md`.

## Data and Caching

When `MONGO_URI` is configured, the backend uses these collections:

- `users`
- `trips`
- `api_cache`

Without MongoDB, local development storage is written under `backend/.data`.
That directory is ignored by Git and is not suitable for multi-instance or
production deployment.

The caching system includes:

- MongoDB cache for summaries, agendas, routes, recommendations, and lookups.
- In-memory service caches for frequently repeated provider calls.
- One weather cache JSON file per trip with fresh and stale-fallback behavior.

## Testing and Validation

Run Flutter tests:

```bash
flutter test
```

Run static analysis:

```bash
flutter analyze
```

The API collection is available at:

```text
postman/SmartTravelPlanner.postman_collection.json
```

Start the backend before running Postman requests. Authentication-dependent
requests need a token from the login response.

## Deployment Summary

### Flutter web

Build with the deployed backend URL:

```bash
flutter build web \
  --dart-define=SELF_API_BASE_URL=https://six005cmd-api.onrender.com/api \
  --dart-define=EXTERNAL_PROXY_BASE_URL=https://six005cmd-api.onrender.com/api/external
```

Firebase Hosting serves `build/web` according to `firebase.json`.

### Express backend

The backend is compatible with a Render Node web service:

```text
Build command: npm install
Start command: npm start
Root directory: backend
```

Configure MongoDB, JWT, CORS, email delivery, and provider keys in the deployment
environment. Do not commit `backend/.env`.

Firebase Hosting serves static files, so Render environment variables are not
available to the Flutter web app. Supply `MAPBOX_ACCESS_TOKEN` with
local ignored `web/mapbox_config.local.json` for local debug and Firebase
builds. Copy `web/mapbox_config.example.json` to
`web/mapbox_config.local.json`, then put your Mapbox public token there. The
token can still be overridden with `--dart-define=MAPBOX_ACCESS_TOKEN=...` when
needed. Do not bundle `backend/.env` into the Flutter web build; it may contain
backend secrets.

## Current Limitations

- Google Places endpoints are demo stubs.
- The summary controller parses `refresh=true`, but the summary service currently
  does not bypass its complete-summary cache or propagate refresh to providers.
- Trip-specific weather endpoints rely on cache expiry and do not currently
  process a refresh query parameter.
- Local fallback storage and in-memory caches are not shared between backend
  instances.

## Additional Documentation

- Backend setup and API reference: `backend/README.md`
- Aggregation design: `backend/API_AGGREGATION.md`
- Flutter API configuration: `lib/core/api/api_config.dart`
- Flutter endpoint contracts: `lib/core/api/api_contract.dart`
