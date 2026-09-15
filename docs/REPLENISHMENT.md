# Replenishment Creation

## Purpose

Create a replenishment session for the currently identified machine so later
commits can add product lines.

```text
Creating a replenishment does not modify inventory.
```

## Preconditions

```text
Authenticated Session
Current Operator
Current Machine
```

Without these contexts the app does not call HTTP.

## API

```http
POST /api/v1/replenishments
Authorization: Bearer <session-jwt>
Content-Type: application/json
Idempotency-Key: <operation-key>
X-Request-Id: <request-id>
```

### Request (`CreateReplenishmentRequest`)

```json
{
  "machine_id": "…",
  "location": {
    "latitude": -35.4264,
    "longitude": -71.6554,
    "accuracy": 12.4
  }
}
```

`location` is required by the NexoVending contract. VendingApp obtains it from
`LocationService` (development uses fixed coordinates until device GPS is
wired). `operator_id` / `tenant_id` are **not** sent — the Session JWT is
authority.

### Response (`ReplenishmentOut`) → **201**

Minimum fields used by the client:

| Field | Notes |
| ----- | ----- |
| `id` | Replenishment id |
| `machine_id` | Must match current machine |
| `status` | Starts as `IN_PROGRESS` |
| `operator_id` | From backend session |
| `lines` | Empty on create |

### Errors

| Status | App handling |
| ------ | ------------ |
| 401 | Clear session → login |
| 403 | No permission to replenish machine |
| 404 | Machine no longer available |
| 409 | Replenishment already in progress / conflict |
| 422 | Validation failure |
| 5xx / network | Recoverable + retry (same Idempotency-Key) |

## Flow

```text
Operator
   ↓
Machine
   ↓
Start replenishment
   ↓
Capture location (LocationService)
   ↓
POST /replenishments
   ↓
Current Replenishment
```

## Lifecycle (this commit)

```text
Create
 ↓
IN_PROGRESS
```

Completion / cancellation arrive in later commits.

## Idempotency

One logical “Start” generates one `Idempotency-Key`. Retries reuse it.
Changing machine or starting a new intent after success generates a new key.
Double-tap while `Creating` does not issue a second POST.

## Inventory

Create does **not**:

* call inventory endpoints;
* decrement stock;
* invent replenishment lines.

## Next step

```text
Current Replenishment
        ↓
Product Lookup
```

See [PRODUCT_LOOKUP.md](PRODUCT_LOOKUP.md). Commit 10 adds replenishment lines.

## Security

* Operator from session (`/operators/me` already loaded).
* Tenant from backend/session context.
* Machine from identification context only.
* JWT / Authorization never logged; Google `id_token` never sent.

## Related

* [MACHINE_DETAIL.md](MACHINE_DETAIL.md)
* [PRODUCT_LOOKUP.md](PRODUCT_LOOKUP.md)
* [ADR-007](adr/ADR-007-replenishment-creation.md)
* [Mobile API Contract](nexovending_API/Mobile_API_Contract_NexoVending.md)
