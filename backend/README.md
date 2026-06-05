# Smart Travel Planner Backend (Express.js)

This folder contains an Express.js backend for your Flutter web app.

## Quick Start

1. Install dependencies:

```bash
cd backend
npm install
```

2. Run in development mode:

```bash
npm run dev
```

3. API base URL:

`http://localhost:3000/api`

This matches `lib/core/api/api_config.dart`.

## Implemented Endpoints

- `GET /api/health`
- `GET /api/trips`
- `GET /api/trips/:id`
- `POST /api/trips`
- `PUT /api/trips/:id`
- `DELETE /api/trips/:id`
- `GET /api/trips/:id/weather`
- `GET /api/trips/:id/weather/forecast`
- `GET /api/trips/:id/google-places`
- `GET /api/trips/:id/recommendations`
- `GET /api/trips/:id/agenda`
- `GET /api/trips/:id/country-info`
- `GET /api/trips/:id/summary`
- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/auth/profile`
- `GET /api/external/weather`
- `GET /api/external/weather/forecast`
- `GET /api/external/google-places`
- `GET /api/external/recommendations`
- `GET /api/external/route`
- `GET /api/external/walking-route`
- `GET /api/external/country-info`
- `GET /api/external/reverse-geocode`

## Notes

- Trip data is persisted locally in `backend/.data/trips.json` for development.
- Auth uses bcrypt password hashes and JWT bearer tokens.
- `GET /api/external/weather`, `GET /api/external/weather/forecast`, `GET /api/trips/:id/weather`, and `GET /api/trips/:id/weather/forecast` use live Open-Meteo data and do not require an API key.
- `GET /api/external/recommendations` and `GET /api/trips/:id/recommendations` use live Foursquare Places data when `FOURSQUARE_API_KEY` is configured in `backend/.env`.
- `GET /api/trips/:id/agenda` builds a timed food/place tour-guide agenda from trip dates, Open-Meteo forecast, Foursquare recommendation groups, Foursquare `open_at` checks, and Google Routes walking paths. Use `availabilityDays=1..7` and `routeMapDays=1..7` to increase live open-at and route-map coverage for demos.
- `GET /api/external/route` uses Google Maps Routes API when `GOOGLE_ROUTES_API_KEY` is configured in `backend/.env`. Pass `mode=walk` for walking routes or `mode=car` / `mode=vehicle` for Vehicle routes. Vehicle uses Google Routes `DRIVE`.
- Local development CORS allows configured origins plus any `localhost`, `127.0.0.1`, or `::1` HTTP/HTTPS port, so Flutter web can run on random debug ports.
- Google Places endpoints are provider-ready stubs returning deterministic payloads.
