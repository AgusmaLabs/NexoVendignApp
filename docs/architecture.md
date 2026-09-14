# VendingApp Architecture

**Status:** Application infrastructure (Commit 2)
**Client:** Flutter
**Backend:** NexoVending public HTTP API

## Role

VendingApp is a Flutter mobile client for NexoVending replenishment operators.

```text
VendingApp
    │
    ▼
NexoVending Public API
```

VendingApp must not consume Nexo Platform internal APIs:

```text
VendingApp
    X
    └──> Nexo Platform internal APIs
```

Flutter captures and presents. NexoVending decides and persists.

## Dependency direction

```text
UI
 ↓
Application
 ↓
Domain
 ↓
Data
 ↓
Core Infrastructure
 ↓
External Systems
```

Core infrastructure must not contain vending business rules.

Only layers that exist should be present in the codebase. Empty layers must not
be created merely to match this diagram.

## Current structure

```text
VendingApp
│
├── app/
│   ├── bootstrap/
│   ├── home/
│   ├── router/
│   └── theme/
│
├── core/
│   ├── config/
│   ├── networking/
│   ├── errors/
│   ├── logging/
│   ├── storage/
│   └── device/
│
└── features/
    └── future
```

```text
lib/
├── app/
│   ├── bootstrap/app_dependencies.dart
│   ├── home/
│   ├── router/
│   ├── theme/
│   └── app.dart
├── core/
│   ├── config/
│   ├── networking/
│   ├── errors/
│   ├── logging/
│   ├── storage/
│   └── device/
└── main.dart
```

Feature modules are intentionally absent until later commits.

## Infrastructure

* `ApiClient` — HTTP access to the public API (`AppConfig.apiBaseUrl`).
* `AppLogger` — centralized logging without secrets.
* `LocalStorage` / `SecureStorage` — injectable persistence contracts.
* `ConnectivityService`, `LocationService`, `BarcodeScanner` — device contracts
  (platform implementations arrive with later commits).
* `AppDependencies` — composition root; widgets must not construct infrastructure.

## Configuration

`AppConfig` holds `environment`, `apiBaseUrl`, and `httpTimeout`. Values are
supplied at bootstrap (for example via `--dart-define`) and exposed through
`AppConfigScope` / `AppDependenciesScope`.

## Navigation and theme

* `AppRouter` owns named routes. The initial route is `/`.
* `AppTheme` owns the global `ThemeData`. Features must not create a second
  global theme.

## Related documents

* [Networking](NETWORKING.md)
* [ADR-001: VendingApp API Boundary](adr/ADR-001-vendingapp-api-boundary.md)
* [Architecture plan (pre-implementation)](architecture-plan.md)
* [Product requirements](PRD.md)
