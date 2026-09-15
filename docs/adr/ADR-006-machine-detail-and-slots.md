# ADR-006: Machine Detail and Physical Slot Representation

- Status: Accepted
- Date: 2026-09-15

## Context

Once a machine is identified, VendingApp needs its physical configuration
before replenishment. Configuration varies across machine deployments and
must not be encoded as rigid client rules (snack vs coffee vs mixed).

## Decision

VendingApp consumes machine detail and slots exclusively from:

```http
GET /api/v1/machines/{machine_id}
GET /api/v1/machines/{machine_id}/slots
```

Slots are treated as physical positions/containers. Preferred product is
configuration metadata, not a fixed SKU assignment or proof of loaded stock.

Detail and slots load concurrently; any failure yields a single Failure state.
Empty slot lists are valid. Slot selection is visual UI state only.

## Consequences

- Mobile presents configured slots; it does not decide existence, capacity,
  preferred product, or machine-type filtering.
- NexoVending remains authority for tenant, machine access, and layout.
- Replenishment commits consume this context later.

## Alternatives considered

### Client-side machine-type slot rules

Rejected — duplicates backend authority and breaks mixed/configurable layouts.

### Treat preferred product as current product

Rejected — contract distinguishes preferred configuration from operational load.
