# VendingApp Architecture

**Status:** Google authentication foundation (Commit 3)
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
│   ├── authentication/
│   ├── config/
│   ├── networking/
│   ├── errors/
│   ├── logging/
│   ├── storage/
│   └── device/
│
└── features/
    └── authentication/
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
│   ├── authentication/
│   ├── config/
│   ├── networking/
│   ├── errors/
│   ├── logging/
│   ├── storage/
│   └── device/
├── features/
│   └── authentication/
│       ├── application/
│       └── presentation/
└── main.dart
```

## Authentication (Commit 3)

```text
Login UI
  → AuthenticationController
  → GoogleSignInService
  → Google Sign-In SDK
  → id_token (memory only)
```

* Official dependency: `google_sign_in`.
* `Authenticated` means Google identity only — **not** a NexoVending session.
* `POST /api/v1/auth/session` is intentionally not implemented yet.

## Infrastructure

* `ApiClient` — HTTP access to the public API (`AppConfig.apiBaseUrl`).
* `AppLogger` — centralized logging without secrets.
* `LocalStorage` / `SecureStorage` — injectable persistence contracts.
* `ConnectivityService`, `LocationService`, `BarcodeScanner` — device contracts
  (platform implementations arrive with later commits).
* `AppDependencies` — composition root; widgets must not construct infrastructure.

## Configuration

`AppConfig` holds `environment`, `apiBaseUrl`, and `httpTimeout`.
`GoogleSignInConfig` holds Google client IDs via `--dart-define`.

## Navigation and theme

* `AppRouter` owns named routes. The initial route is `/login`.
* `AppTheme` owns the global `ThemeData`. Features must not create a second
  global theme.

## Related documents

* [Authentication](AUTHENTICATION.md)
* [Networking](NETWORKING.md)
* [ADR-001: VendingApp API Boundary](adr/ADR-001-vendingapp-api-boundary.md)
* [ADR-002: Google Sign-In Boundary](adr/ADR-002-google-sign-in-boundary.md)
* [Architecture plan (pre-implementation)](architecture-plan.md)
* [Product requirements](PRD.md)
