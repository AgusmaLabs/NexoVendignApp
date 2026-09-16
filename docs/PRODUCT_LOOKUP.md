# Product Lookup

## Purpose

Scan or type a barcode and resolve the catalog product from NexoVending.
When the barcode is unknown, continue the cascade: retry → text search →
PENDING line with manual description (Commit 11).

```text
Product catalog authority = NexoVending
UnresolvedProduct ≠ Product
```

## Preconditions

```text
Authenticated Session
Current Operator
Current Machine
Current Replenishment
```

Without an active replenishment the lookup UI is blocked.

## API

### Barcode lookup

```http
GET /api/v1/products/barcode/{barcode}
Authorization: Bearer <session-jwt>
X-Request-Id: <request-id>
```

### Catalog text search (after 404 + retry)

```http
GET /api/v1/products?q={text}&limit={n}&offset={n}
Authorization: Bearer <session-jwt>
```

**200** returns `ProductOut[]`. An empty list is success (not an error).
Search never creates products.

## Cascade

```text
Scan / Manual barcode
        ↓
lookupByBarcode
        ↓
Found → add RESOLVED line
        ↓
NotFound → retry
        ↓
searchByText (GET /products?q=)
        ↓
Select product → Found → RESOLVED line
        ↓
Empty / discard → UnresolvedProduct
        ↓
POST line PENDING (manual_description, product_id null)
```

## Models

* `Product` — catalog identity (`ProductOut`).
* `UnresolvedProduct` — operational snapshot for PENDING (`manual_description` + optional barcode). Not a catalog product.

## States

```text
Idle → Scanning → LookingUp → Found
LookingUp → NotFound
NotFound → SearchingByDescription → SearchResults | SearchEmpty
SearchEmpty / NotFound → EnteringManualDescription → UnresolvedReady
LookingUp / Searching → Failure
```

## Scanner

* Abstraction: `BarcodeScanner` (`lib/core/device/`)
* Device adapter: `MobileBarcodeScanner` (`mobile_scanner`)
* Manual entry uses the same `lookupByBarcode` path
* Cancelled scan (`null`) performs no HTTP

## Limits

* Does not create catalog products
* Does not invent `product_id`
* Does not run admin resolve / pending queue UI

## Security

* Session JWT only via ApiClient Bearer
* Google `id_token` never sent
* No client `tenant_id` on lookup/search

## Related

* [REPLENISHMENT.md](REPLENISHMENT.md)
* [REPLENISHMENT_LINES.md](REPLENISHMENT_LINES.md)
* [ADR-008](adr/ADR-008-product-catalog-authority.md)
* [ADR-010](adr/ADR-010-unresolved-product-cascade.md)
* [Mobile API Contract](nexovending_API/Mobile_API_Contract_NexoVending.md)
