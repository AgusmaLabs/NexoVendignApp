# ADR-008: Product Catalog Authority

- Status: Accepted
- Date: 2026-09-15

## Context

During replenishment operators need to identify products by barcode. The
catalog must remain authoritative in NexoVending so Flutter does not invent
or persist products.

## Decision

VendingApp looks up products exclusively via NexoVending:

```http
GET /api/v1/products/barcode/{barcode}
GET /api/v1/products?q={text}&limit={n}&offset={n}
```

using the Session JWT. A barcode 404 means “unknown in catalog”, never “create
locally”. Text search never creates products either.

Flutter only:

* captures barcode (camera or manual);
* optionally searches the published catalog by description;
* presents the returned product;
* for still-unknown items, captures `UnresolvedProduct` and posts a PENDING line
  (see ADR-010).

## Consequences

- No parallel mobile catalog.
- Unknown barcodes follow the cascade (retry → search → PENDING), not client product creation.
- Catalog changes in backend do not require client business-rule changes.

## Alternatives considered

### Local product cache as source of truth

Rejected — duplicates authority and drifts from tenant catalog.
