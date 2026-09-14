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

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and
[docs/adr/ADR-001-vendingapp-api-boundary.md](docs/adr/ADR-001-vendingapp-api-boundary.md).

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
  --dart-define=API_BASE_URL=http://localhost:8080
```

Supported `APP_ENV` values: `development`, `staging`, `production`.

## Status

This repository currently contains the **Flutter foundation** only:

* application shell (`VendingApp`);
* centralized router and theme;
* injectable `AppConfig`;
* placeholder home screen;
* unit / widget / smoke tests;
* static analysis and CI.

Business capabilities (authentication, machines, products, replenishments) and
NexoVending API integration will be added in subsequent commits.
