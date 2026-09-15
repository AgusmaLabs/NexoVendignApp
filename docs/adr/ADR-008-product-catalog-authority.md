# ADR-008: Product Catalog Authority

- Status: Accepted
- Date: 2026-09-15

## Context

During replenishment operators need to identify products by barcode. The
catalog must remain authoritative in NexoVending so Flutter does not invent
or persist products.

## Decision

VendingApp looks up products exclusively via:

```http
GET /api/v1/products/barcode/{barcode}
```

using the Session JWT. A 404 means “unknown in catalog”, never “create locally”.

Flutter only:

* captures barcode (camera or manual);
* presents the returned product;
* hands the `Product` to later replenishment-line flow.

## Consequences

- No parallel mobile catalog.
- Unknown barcodes stay unresolved until a later commit.
- Catalog changes in backend do not require client business-rule changes.

## Alternatives considered

### Local product cache as source of truth

Rejected — duplicates authority and drifts from tenant catalog.
