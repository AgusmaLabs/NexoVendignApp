# ADR-004: Vending Operator Bootstrap

- Status: Accepted
- Date: 2026-09-15

## Context

After Google Sign-In and `POST /api/v1/auth/session`, VendingApp holds a
Session JWT. That JWT proves authentication, but does not by itself define
the Vending **Operator** identity used for field operations.

## Decision

After establishing an authenticated NexoVending session, VendingApp resolves
the current Vending operator through:

```http
GET /api/v1/operators/me
Authorization: Bearer <session-jwt>
```

Flutter must not invent operators, roles, or entitlements locally.

## Consequences

```text
Session != Operator
```

```text
Valid JWT != Valid Vending Operator
```

- Operator bootstrap is mandatory before the operational shell.
- Authorization for machines/replenishments remains on NexoVending.
- Future features consume `Operator` as display/context only.

## Alternatives considered

### Trust JWT claims as Operator

Rejected — Vending Operator policies live in NexoVending, not token claims.

### Skip `/operators/me` until first machine call

Rejected — operators without provisioning would reach the shell incorrectly.
