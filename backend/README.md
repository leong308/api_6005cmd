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
- `GET /api/trips/:id/google-places`
- `GET /api/trips/:id/recommendations`
- `GET /api/trips/:id/country-info`
- `GET /api/trips/:id/summary`
- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/auth/profile`
- `GET /api/external/weather`
- `GET /api/external/google-places`
- `GET /api/external/recommendations`
- `GET /api/external/country-info`

## Notes

- Trip data is persisted locally in `backend/.data/trips.json` for development.
- Auth uses bcrypt password hashes and JWT bearer tokens.
- External endpoints are provider-ready stubs returning deterministic payloads.
