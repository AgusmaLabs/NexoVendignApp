# ADR-009 — Replenishment line authority

## Context

After product lookup, the operator must record what is being loaded into a
machine as a replenishment line (product, quantity, slot). Inventory effects
and business validation belong to NexoVending, not the Flutter client.

## Decision

Replenishment line creation is executed exclusively through NexoVending:

```http
POST /api/v1/replenishments/{id}/lines
```

VendingApp:

* captures product (from lookup);
* captures quantity;
* captures slot from machine configuration;
* sends the request with Session JWT + Idempotency-Key;
* presents success / failure and updates Current Replenishment from the
  returned `ReplenishmentOut`.

NexoVending:

* validates product, quantity, slot, capacity, permissions;
* authorizes tenant / operator access;
* persists the line;
* remains inventory authority.

VendingApp does not:

* invent quantity caps;
* hardcode snack/coffee slot rules;
* treat `preferred_product_id` as a fixed SKU requirement;
* mutate local inventory;
* complete or cancel the replenishment in this flow.

## Consequences

* Line create is capture + presentation only.
* Idempotent retries reuse the same key for one operator intent.
* Slot optionality follows the public contract (currently required).

## Alternatives considered

* Local-only line draft before sync — rejected; backend remains source of truth.
* Inferring slots from machine type — rejected; violates ADR-014 / machine
  configuration from API.
