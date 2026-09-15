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

* [docs/architecture.md](docs/architecture.md)
* [docs/AUTHENTICATION.md](docs/AUTHENTICATION.md)
* [docs/SESSION.md](docs/SESSION.md)
* [docs/OPERATOR_BOOTSTRAP.md](docs/OPERATOR_BOOTSTRAP.md)
* [docs/MACHINE_IDENTIFICATION.md](docs/MACHINE_IDENTIFICATION.md)
* [docs/NETWORKING.md](docs/NETWORKING.md)
* [docs/adr/ADR-001-vendingapp-api-boundary.md](docs/adr/ADR-001-vendingapp-api-boundary.md)
* [docs/adr/ADR-002-google-sign-in-boundary.md](docs/adr/ADR-002-google-sign-in-boundary.md)
* [docs/adr/ADR-003-session-token-storage.md](docs/adr/ADR-003-session-token-storage.md)
* [docs/adr/ADR-004-operator-bootstrap.md](docs/adr/ADR-004-operator-bootstrap.md)
* [docs/adr/ADR-005-machine-identification.md](docs/adr/ADR-005-machine-identification.md)

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
  --dart-define=TENANT_ID=tenant-a \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=your-web-client-id.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=your-ios-client-id.apps.googleusercontent.com
```

Supported `APP_ENV` values: `development`, `staging`, `production`.

## Status

Implemented through Commit 6:

* application shell and infrastructure;
* Google Sign-In → Session JWT → SecureStorage;
* operator bootstrap via `GET /api/v1/operators/me`;
* machine identification via `GET /api/v1/machines/resolve`.

Machine detail/slots, products, and replenishments arrive in subsequent commits.
