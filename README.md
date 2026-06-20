# Smart Travel Planner (Flutter + Express)

This workspace contains:

- Flutter web UI (`lib/`)
- Express.js backend (`backend/`)

## Run Flutter UI

Copy `.env.example` to `.env` and set a public Mapbox access token:

```dotenv
MAPBOX_ACCESS_TOKEN=pk.your_public_token
```

```bash
flutter pub get
flutter run -d chrome
```

The app renders Mapbox Streets, Outdoors, and Light vector styles through the
cross-platform map widget, including pitched 3D building extrusions on web and
mobile.

## Run Express Backend

```bash
cd backend
npm install
npm run dev
```

Backend base URL: `http://localhost:3000/api`

## API Contracts

Contracts used by Flutter are in:

- `lib/core/api/api_config.dart`
- `lib/core/api/api_contract.dart`

You can override API URLs at build/run time:

```bash
flutter run -d chrome --dart-define=SELF_API_BASE_URL=http://localhost:3000/api --dart-define=EXTERNAL_PROXY_BASE_URL=http://localhost:3000/api/external
```

`MAPBOX_ACCESS_TOKEN` can also be supplied with `--dart-define`; this takes
precedence over the value loaded from `.env`.
