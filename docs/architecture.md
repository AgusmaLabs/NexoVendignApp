# VendingApp Architecture

**Status:** Operator bootstrap (Commit 5)
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

## Identity stack

```text
Google Identity
      ↓
NexoVending Session
      ↓
Vending Operator
      ↓
Vending Features
```

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

## Current structure

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
│   ├── time/
│   └── device/
├── features/
│   ├── authentication/
│   │   ├── application/
│   │   └── presentation/
│   └── operator/
│       ├── application/
│       ├── data/
│       ├── domain/
│       └── presentation/
└── main.dart
```

## Authentication + session + operator

```text
AuthGate
  → Login (Google → Session)
  → OperatorBootstrapController
  → GET /api/v1/operators/me
  → Operator home shell
```

* Session JWT authority: authentication.
* `/operators/me` authority: Vending operator identity.
* Flutter does not fabricate operators or authorize replenishment.

## Infrastructure

* `ApiClient` — HTTP access; optional `authenticated: true` attaches Bearer.
* `SessionService` / `SecureStorage` — session persistence.
* `OperatorService` — operator bootstrap only.
* `AppDependencies` — composition root.

## Configuration

`AppConfig` holds `environment`, `apiBaseUrl`, `tenantId`, and `httpTimeout`.
Google client IDs via `--dart-define`.

## Navigation and theme

* `AppRouter` initial route `/login` → `AuthGate`.
* `AppTheme` owns global `ThemeData`.

## Related documents

* [Authentication](AUTHENTICATION.md)
* [Session](SESSION.md)
* [Operator Bootstrap](OPERATOR_BOOTSTRAP.md)
* [Networking](NETWORKING.md)
* [ADR-001](adr/ADR-001-vendingapp-api-boundary.md)
* [ADR-002](adr/ADR-002-google-sign-in-boundary.md)
* [ADR-003](adr/ADR-003-session-token-storage.md)
* [ADR-004](adr/ADR-004-operator-bootstrap.md)
* [Product requirements](PRD.md)
