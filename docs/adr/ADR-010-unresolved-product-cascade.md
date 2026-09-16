# ADR-010 — Unresolved Product Cascade

## Status

Accepted

## Context

Barcode lookup may return **404**. Operators still need to record the field
observation without inventing catalog identity. NexoVending V11 supports
`pending_product_resolution` lines and publishes catalog text search
(`GET /products?q=`).

## Decision

VendingApp implements a fixed cascade:

1. Barcode lookup
2. Retry (same barcode path)
3. Catalog text search (`GET /api/v1/products?q=&limit=&offset=`)
4. PENDING line with `manual_description` (and optional scanned barcode)

`UnresolvedProduct` is a capture model for PENDING input — **not** a `Product`.
No client-side `product_id` is invented. Search uses the published API only
(no embedded catalog). PENDING posts omit a real product id (`product_id: null`)
and never send `replacement_reason`.

## Consequences

- Operators can continue the visit with pending lines.
- Catalog resolution remains a backend/admin concern.
- Complete may succeed with pending lines; SKU stock completeness waits on resolve.

## Alternatives considered

- Local draft-only unresolved lines — rejected; V11 persists PENDING.
- Skip search and jump to manual description — rejected; violates cascade priority.
- Client product creation — rejected; catalog authority is NexoVending.
