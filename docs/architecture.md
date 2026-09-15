# VendingApp Architecture

**Status:** Replenishment lines (Commit 10)
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
Session JWT
      ↓
Vending Operator
      ↓
Current Machine
      ↓
Current Replenishment
      ↓
Product Lookup
      ↓
Replenishment Lines
      ↓
Completion
      ↓
Backend Inventory Transaction
```

```text
Create Replenishment
        ≠
Inventory Movement

Product Lookup
        ≠
Replenishment Line

Replenishment Line
        ≠
Inventory Movement
```

```text
Catalog authority        = NexoVending
Replenishment authority  = NexoVending
Inventory authority      = NexoVending

VendingApp               = capture + presentation + API consumer
```

## Dependency direction

```text
Presentation
    ↓
Application
    ↓
Domain
    ↓
Infrastructure / Data
    ↓
NexoVending API
```

Core infrastructure must not contain vending business rules.

## Current structure

```text
lib/
├── app/
├── core/
│   └── device/   (BarcodeScanner, LocationService, …)
├── features/
│   ├── authentication/
│   ├── operator/
│   ├── machine/
│   ├── replenishment/
│   └── products/
└── main.dart
```

## Authentication + machine + replenishment + product + line

```text
AuthGate
  → operators/me
  → machines/resolve
  → machine detail + slots
  → POST /replenishments
  → GET /products/barcode/{barcode}
  → POST /replenishments/{id}/lines
```

```text
Product
   ↓
Replenishment Line
```

## Infrastructure

* `ApiClient` — Bearer + request IDs
* `ReplenishmentService` / `ReplenishmentLineService` / `ProductLookupService`
* `BarcodeScanner` → `MobileBarcodeScanner` (`mobile_scanner`)
* `LocationService` — GPS for replenishment create
* `AppDependencies` — composition root

## Navigation

`/login` → `/machines/identify` → `/machines/detail` →
`/replenishments/start` → `/products/lookup` → `/replenishments/lines/add`

## Related documents

* [Authentication](AUTHENTICATION.md)
* [Session](SESSION.md)
* [Operator Bootstrap](OPERATOR_BOOTSTRAP.md)
* [Machine Identification](MACHINE_IDENTIFICATION.md)
* [Machine Detail](MACHINE_DETAIL.md)
* [Replenishment](REPLENISHMENT.md)
* [Product Lookup](PRODUCT_LOOKUP.md)
* [Replenishment Lines](REPLENISHMENT_LINES.md)
* [Networking](NETWORKING.md)
* [ADR-001](adr/ADR-001-vendingapp-api-boundary.md)
* [ADR-002](adr/ADR-002-google-sign-in-boundary.md)
* [ADR-003](adr/ADR-003-session-token-storage.md)
* [ADR-004](adr/ADR-004-operator-bootstrap.md)
* [ADR-005](adr/ADR-005-machine-identification.md)
* [ADR-006](adr/ADR-006-machine-detail-and-slots.md)
* [ADR-007](adr/ADR-007-replenishment-creation.md)
* [ADR-008](adr/ADR-008-product-catalog-authority.md)
* [ADR-009](adr/ADR-009-replenishment-line-authority.md)
* [Product requirements](PRD.md)
