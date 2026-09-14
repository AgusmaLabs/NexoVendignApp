# VendingApp Architecture

**Status:** Foundation (Commit 1)
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
Presentation
      ↓
Application
      ↓
Domain
      ↓
Data
      ↓
External
```

Only layers that exist should be present in the codebase. Empty layers must not
be created merely to match this diagram.

## Current structure

```text
lib/
├── app/
│   ├── home/
│   ├── router/
│   ├── theme/
│   └── app.dart
├── core/
│   └── config/
└── main.dart
```

This commit establishes the application shell only. Feature modules and
infrastructure (networking, storage, device) arrive in later commits.

## Configuration

`AppConfig` holds environment and `apiBaseUrl`. Values are supplied at bootstrap
(for example via `--dart-define`) and exposed through `AppConfigScope`. Widgets
must not hardcode environment-specific endpoints.

## Navigation and theme

* `AppRouter` owns named routes. The initial route is `/`.
* `AppTheme` owns the global `ThemeData`. Features must not create a second
  global theme.

## Related documents

* [ADR-001: VendingApp API Boundary](adr/ADR-001-vendingapp-api-boundary.md)
* [Architecture plan (pre-implementation)](architecture-plan.md)
* [Product requirements](PRD.md)
