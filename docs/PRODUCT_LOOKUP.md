# Product Lookup

## Purpose

Scan or type a barcode and resolve the catalog product from NexoVending.
Does **not** add a replenishment line.

```text
Product catalog authority = NexoVending
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

```http
GET /api/v1/products/barcode/{barcode}
Authorization: Bearer <session-jwt>
X-Request-Id: <request-id>
```

### Response (`ProductOut`) → **200**

```json
{
  "product_id": "…",
  "barcode": "7801234567890",
  "name": "Coca Cola 350 ml",
  "status": "ACTIVE",
  "unit": "CAN"
}
```

### Errors

| Status | App handling |
| ------ | ------------ |
| 401 | Clear session → login |
| 403 | Access denied |
| 404 | Product not found (not create) |
| 422 | Invalid barcode |
| 429 | Rate limited |
| 5xx / network | Recoverable + retry |

## Flow

```text
Current Replenishment
        ↓
Scan / Manual barcode
        ↓
ProductLookupService.lookupByBarcode
        ↓
Found | NotFound | Failure
```

## Model

`Product` mirrors `ProductOut`. UI `description` maps to backend `name`.
Equality is by `product_id`.

## States

```text
Idle → Scanning → LookingUp → Found
LookingUp → NotFound
LookingUp → Failure
```

## Scanner

* Abstraction: `BarcodeScanner` (`lib/core/device/`)
* Device adapter: `MobileBarcodeScanner` (`mobile_scanner`)
* Manual entry uses the same `lookupByBarcode` path
* Cancelled scan (`null`) performs no HTTP

## Limits (this commit)

* No replenishment lines
* No quantity / slot
* No inventory mutation
* No local catalog
* No product creation

## Security

* Session JWT only via ApiClient Bearer
* Google `id_token` never sent
* No client `tenant_id` on lookup

## Related

* [REPLENISHMENT.md](REPLENISHMENT.md)
* [ADR-008](adr/ADR-008-product-catalog-authority.md)
* [Mobile API Contract](nexovending_API/Mobile_API_Contract_NexoVending.md)
