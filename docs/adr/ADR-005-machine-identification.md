# ADR-005: Machine Identification Boundary

- Status: Accepted
- Date: 2026-09-15

## Context

Once authenticated and resolved as a Vending operator, the app must select
the machine for field operations.

## Decision

VendingApp identifies machines exclusively through:

```http
GET /api/v1/machines/resolve
```

using the Session JWT. Flutter performs only empty-input validation and
maps the raw value to `QR_CODE` / `INTERNAL_ID` per the public contract.

NexoVending remains the authority for existence, tenant, and access.

## Consequences

- Current machine is application state (in-memory), not local authority.
- Slots / replenishment consume this context in later commits.
- No tenant selector and no local machine authorization rules.

## Alternatives considered

### Local machine registry

Rejected — duplicates backend authority.

### Skip resolve and type machine UUID only

Rejected — operators primarily use operational/QR codes in the field.
