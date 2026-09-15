# VendingApp

VendingApp is the mobile application used by NexoVending replenishment operators.

## Architecture

```text
VendingApp
    │
    │ HTTPS / Public API
    ▼
NexoVending
```

VendingApp is an **external client**.

It must not access directly:

* NexoVending databases;
* backend repositories;
* internal infrastructure;
* Nexo Platform internals.

The public NexoVending HTTP API is the only integration boundary.

See:

* [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
* [docs/AUTHENTICATION.md](docs/AUTHENTICATION.md)
* [docs/NETWORKING.md](docs/NETWORKING.md)
* [docs/adr/ADR-001-vendingapp-api-boundary.md](docs/adr/ADR-001-vendingapp-api-boundary.md)
* [docs/adr/ADR-002-google-sign-in-boundary.md](docs/adr/ADR-002-google-sign-in-boundary.md)

## Tooling

| Tool    | Version   |
| ------- | --------- |
| Flutter | 3.47.3    |
| Dart    | 3.13.3    |

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Optional compile-time configuration:

```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=HTTP_TIMEOUT_MS=30000 \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=your-web-client-id.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=your-ios-client-id.apps.googleusercontent.com
```

Supported `APP_ENV` values: `development`, `staging`, `production`.

Google Sign-In platform setup is documented in [docs/AUTHENTICATION.md](docs/AUTHENTICATION.md).

## Status

This repository currently contains:

* application shell (`VendingApp`);
* centralized router and theme (initial route `/login`);
* injectable `AppConfig` and `AppDependencies`;
* `ApiClient` with request IDs, timeouts, and error mapping;
* Google Sign-In foundation (`GoogleSignInService` + login UI);
* logging, local/secure storage contracts, and device abstractions;
* unit / widget / integration tests with a fake Google provider;
* static analysis and CI.

NexoVending session exchange (`POST /api/v1/auth/session`), operator bootstrap,
machines, products, and replenishments arrive in subsequent commits.
