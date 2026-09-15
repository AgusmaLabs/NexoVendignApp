# Machine Identification

## Purpose

After operator bootstrap, the operator identifies the machine they will
operate on using NexoVending's public resolve API.

```text
The mobile application does not decide which machines exist or whether
the operator may access them. NexoVending is the authority.
```

## API

```http
GET /api/v1/machines/resolve?identifier_type={type}&value={value}
Authorization: Bearer <session-jwt>
```

| Query | Values |
| ----- | ------ |
| `identifier_type` | `QR_CODE` or `INTERNAL_ID` |
| `value` | Operational code or machine UUID |

**200 `MachineOut`** (fields used in this commit):

```json
{
  "machine_id": "…",
  "identifier": "MIX-001",
  "machine_type": "SNACK",
  "name": "Lobby",
  "status": "ACTIVE"
}
```

Slots may be present in the resolve payload but are loaded explicitly via
the dedicated slots endpoint (see [MACHINE_DETAIL.md](MACHINE_DETAIL.md)).

### Errors

| Status | App handling |
| ------ | ------------ |
| 401 | Clear session → login |
| 403 | Access denied |
| 404 | Machine not found |
| 422 | Request validation |
| 5xx / network | Recoverable failure + retry |

## Flow

```text
Operator
   ↓
Machine identifier
   ↓
MachineService
   ↓
Authenticated ApiClient
   ↓
NexoVending
   ↓
Machine context
   ↓
Machine detail + slots
```

Client maps UUID-shaped values to `INTERNAL_ID` and other values to
`QR_CODE`. Empty input is rejected before HTTP.

## State machine

```text
Initial → Resolving → Resolved
Resolving → Failure → Retry → Resolving
```

Failed identification does **not** replace an already selected machine.

From `Resolved`, the operator continues to machine detail/slots.

## Security

* JWT only via centralized Bearer attachment.
* Google `id_token` is never sent to machine endpoints.
* Machine context is in-memory only (not authority, not SecureStorage).
* No client-supplied `tenant_id` on resolve.

## Related

* [OPERATOR_BOOTSTRAP.md](OPERATOR_BOOTSTRAP.md)
* [MACHINE_DETAIL.md](MACHINE_DETAIL.md)
* [ADR-005](adr/ADR-005-machine-identification.md)
* [ADR-006](adr/ADR-006-machine-detail-and-slots.md)
* [Mobile API Contract](nexovending_API/Mobile_API_Contract_NexoVending.md)
