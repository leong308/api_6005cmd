# Smart Travel Planner (Flutter + Express)

This workspace contains:

- Flutter web UI (`lib/`)
- Express.js backend (`backend/`)

## Run Flutter UI

```bash
flutter pub get
flutter run -d chrome
```

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
