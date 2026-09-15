# ADR-007: Replenishment Creation Boundary

- Status: Accepted
- Date: 2026-09-15

## Context

After identifying a machine, the operator must open a replenishment session
before scanning products. Creation is a backend transaction; inventory must
not change yet.

## Decision

VendingApp creates replenishments exclusively via:

```http
POST /api/v1/replenishments
```

using the Session JWT, current `machine_id`, GPS `location` from
`LocationService`, and an `Idempotency-Key` for the create intent.

NexoVending remains authority for operator, tenant, authorization, status,
persistence, and future inventory effects.

## Consequences

- App holds `Current Replenishment` in memory.
- Create does not add lines or mutate inventory.
- Backend status strings (e.g. `IN_PROGRESS`) are preserved.
- Double-tap and retry respect idempotency semantics.

## Alternatives considered

### Local draft replenishment without POST

Rejected — breaks server authority and conflict handling.

### Client-supplied operator_id / tenant_id

Rejected — duplicates session claims and weakens tenant isolation.
