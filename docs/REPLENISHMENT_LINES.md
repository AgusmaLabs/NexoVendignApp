# Replenishment Lines

## Purpose

Add a line to the current replenishment: either a **RESOLVED** catalog product
or a **PENDING** unresolved observation (`manual_description`).

```text
Creating a replenishment line does not modify inventory.
```

## Preconditions

```text
Authenticated Session
Current Operator
Current Machine
Current Replenishment (IN_PROGRESS)
Product (from lookup/search)  OR  UnresolvedProduct (after cascade)
Machine slots (from machine detail)
```

## Model

`ReplenishmentLine` mirrors NexoVending `ReplenishmentLineOut`:

* `id`, `slot_id`, `quantity`, `unit_price`, `occurred_at`
* `product_description_snapshot`, `resolution_status`
* optional `product_id`, barcode / resolution metadata

`Replenishment.lines` holds the current list after each successful add.

## API

```http
POST /api/v1/replenishments/{replenishment_id}/lines
Authorization: Bearer <session-jwt>
Content-Type: application/json
Idempotency-Key: <operation-key>
X-Request-Id: <request-id>
```

### RESOLVED

```json
{
  "slot_id": "slot-A01",
  "quantity": 12,
  "product_id": "prod-1"
}
```

### PENDING

```json
{
  "slot_id": "slot-A01",
  "quantity": 5,
  "barcode": "123456789",
  "manual_description": "Bebida energética X",
  "product_id": null
}
```

`tenant_id` / `operator_id` are **not** sent — Session JWT is authority.
PENDING lines omit `replacement_reason`.

### Response → **200** `ReplenishmentOut`

The full replenishment (including updated `lines`) replaces Current Replenishment.

## Flow

```text
Product Lookup Found  OR  UnresolvedReady
        ↓
Quantity
        ↓
Slot (required by current contract)
        ↓
POST .../lines
        ↓
Current Replenishment.lines updated
```

## Quantity

Mobile UX requires `quantity` as a positive integer (`>= 1`).

No client-side maximum is invented; capacity rules stay in NexoVending.

## Slot

Slots come from machine detail (`MachineSlot` = physical container).

* No snack/coffee hardcoding.
* `preferred_product_id` is configuration, not a mandatory SKU match.
* Empty slot list blocks add until the backend provides slots.
* If a future contract makes `slot_id` optional, the client must follow that
  contract — today it is required.

## States

```text
Idle → Adding → Added
Idle → ValidationFailure
Adding → Failure (retry reuses Idempotency-Key)
Adding → SessionExpired
```

Double-tap while `Adding` does not issue a second POST.

## Errors

| Status / case | App handling |
| ------------- | ------------ |
| Local quantity / slot | ValidationFailure, no HTTP |
| 401 | Clear session → login |
| 403 | Access denied |
| 404 | Replenishment / product / slot not found |
| 409 | Conflict |
| 422 | Validation failed |
| 429 | Rate limited |
| 5xx / network / timeout | Failure + retry (same key) |

## Security

* Session JWT only via `ApiClient`.
* Google `id_token` never sent.
* JWT / Authorization never logged.
* Line stays bound to Current Replenishment / machine context.

## Limits of this commit

Does **not** implement:

* complete / cancel replenishment;
* edit / delete line (no public endpoints used);
* local inventory mutation;
* offline sync;
* admin resolve of pending product lines.

Supports RESOLVED lines (known `product_id`) and PENDING lines
(`manual_description`, `product_id` null) after the Commit 11 cascade.

## Related

* [REPLENISHMENT.md](REPLENISHMENT.md)
* [PRODUCT_LOOKUP.md](PRODUCT_LOOKUP.md)
* [MACHINE_DETAIL.md](MACHINE_DETAIL.md)
* [ADR-009](adr/ADR-009-replenishment-line-authority.md)
* [ADR-010](adr/ADR-010-unresolved-product-cascade.md)
* [Mobile API Contract](nexovending_API/Mobile_API_Contract_NexoVending.md)
