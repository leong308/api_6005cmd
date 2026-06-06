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

3. Add your MongoDB settings to `backend/.env`:

```env
MONGO_URI=mongodb+srv://<db_username>:<db_password>@<cluster-host>/smart_travel_planner?retryWrites=true&w=majority
MONGO_DB_NAME=smart_travel_planner
JWT_SECRET=replace_with_a_long_random_secret
JWT_EXPIRES_IN=7d
PUBLIC_API_BASE_URL=http://localhost:3000
PUBLIC_APP_BASE_URL=http://localhost:5173
EMAIL_PROVIDER=firebase
FIREBASE_AUTH_API_KEY=replace_with_your_firebase_web_api_key
FIREBASE_AUTH_REQUEST_TIMEOUT_MS=10000
EMAIL_VERIFICATION_EXPIRES_IN_MS=7200000
PASSWORD_RESET_EXPIRES_IN_MS=7200000
UNVERIFIED_ACCOUNT_CLEANUP_INTERVAL_MS=600000
```

4. API base URL:

`http://localhost:3000/api`

This matches `lib/core/api/api_config.dart`.

## Render Environment Variables

In Render, open your backend web service, then go to **Environment** →
**Environment Variables**. Set these deployment values:

```env
CORS_ORIGIN=https://smart-trip-planner.web.app
PUBLIC_API_BASE_URL=https://six005cmd-api.onrender.com
PUBLIC_APP_BASE_URL=https://smart-trip-planner.web.app
EMAIL_PROVIDER=firebase
FIREBASE_AUTH_API_KEY=<your_firebase_web_api_key>
FIREBASE_AUTH_REQUEST_TIMEOUT_MS=10000
```

Do not set `PORT`, `NODE_ENV=development`, or SMTP variables on Render Free.
Render provides `PORT`, and Render Free blocks outbound SMTP ports. The Firebase
web API key is in Firebase Console → Project settings → General → Web API Key.

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
- `GET /api/auth/verify-email?token=<verification_token>`
- `POST /api/auth/resend-verification`
- `POST /api/auth/forgot-password`
- `GET /api/auth/reset-password?token=<reset_token>`
- `POST /api/auth/reset-password`
- `POST /api/auth/login`
- `GET /api/auth/profile`
- `POST /api/auth/complete-tour`
- `GET /api/external/weather`
- `GET /api/external/weather/forecast`
- `GET /api/external/google-places`
- `GET /api/external/recommendations`
- `GET /api/external/route`
- `GET /api/external/walking-route`
- `GET /api/external/country-info`
- `GET /api/external/reverse-geocode`

## Notes

- Trip and auth data use MongoDB when `MONGO_URI` is configured. Without `MONGO_URI`, the backend falls back to local development storage in `backend/.data/trips.json`.
- MongoDB collections used by the backend are `trips`, `users`, and `api_cache`.
- Users are stored in the `users` collection. Trips are stored in the `trips` collection with `ownerUserId`, so each logged-in account only sees its own trips and summaries.
- Trip summaries, trip weather/forecast/country/agenda responses, and recommendation lookups read MongoDB cache first. External APIs are called only when the cache does not already contain matching data.
- Auth uses bcrypt password hashes, email verification, and JWT bearer tokens. Register first, open the verification link, then log in. Send the returned token as `Authorization: Bearer <token>` for all `/api/trips/*`, `/api/trips/:id/summary`, and `/api/auth/profile` requests.
- `JWT_SECRET` must be configured for real deployments. Production startup fails if it is missing, rather than silently signing tokens with a placeholder secret.
- Email verification links expire after 2 hours by default. Unverified accounts whose verification link has expired are automatically deleted by the backend cleanup job.
- Forgot-password reset links expire after 2 hours by default. The reset link opens a simple backend-hosted form and clears the reset token after the password is changed.
- The `users.firstLogin` flag is stored in the database. Login returns it to Flutter, and `POST /api/auth/complete-tour` flips it to `false` after the one-time app tour completes.
- Email verification and password reset emails use `EMAIL_PROVIDER=firebase` by default. Firebase Authentication sends the emails over HTTPS, so it works on Render Free and does not require owning a sender domain. Enable Email/Password in Firebase Authentication and set `FIREBASE_AUTH_API_KEY`.
- Resend is still supported with `EMAIL_PROVIDER=resend` and `RESEND_API_KEY`, but it requires a verified sender domain before sending to arbitrary recipients. SMTP is also supported with `EMAIL_PROVIDER=smtp`, but do not use SMTP on Render Free. In non-production, non-Firebase delivery failures return `devVerificationUrl` or `devResetUrl` instead of blocking signup/reset.
- `GET /api/external/weather`, `GET /api/external/weather/forecast`, `GET /api/trips/:id/weather`, and `GET /api/trips/:id/weather/forecast` use live Open-Meteo data and do not require an API key.
- `GET /api/external/recommendations` and `GET /api/trips/:id/recommendations` use live Foursquare Places data when `FOURSQUARE_API_KEY` is configured in `backend/.env`.
- `GET /api/trips/:id/agenda` builds a timed food/place tour-guide agenda from trip dates, Open-Meteo forecast, Foursquare recommendation groups, Foursquare `open_at` checks, and Google Routes walking paths. Use `availabilityDays=1..7` and `routeMapDays=1..7` to increase live open-at and route-map coverage for demos.
- `GET /api/external/route` uses Google Maps Routes API when `GOOGLE_ROUTES_API_KEY` is configured in `backend/.env`. Pass `mode=walk` for walking routes or `mode=car` / `mode=vehicle` for Vehicle routes. Vehicle uses Google Routes `DRIVE`.
- Local development CORS allows configured origins plus any `localhost`, `127.0.0.1`, or `::1` HTTP/HTTPS port, so Flutter web can run on random debug ports.
- Google Places endpoints are provider-ready stubs returning deterministic payloads.
