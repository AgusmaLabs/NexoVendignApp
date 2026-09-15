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

Slots may be present in the payload but are not consumed until Commit 7.

### Errors

| Status | App handling |
| ------ | ------------ |
| 401 | Clear session → login |
| 403 | Access denied |
| 404 | Machine not found |
| 422 | Invalid validation |
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
```

Client maps UUID-shaped values to `INTERNAL_ID` and other values to
`QR_CODE`. Empty input is rejected before HTTP.

## State machine

```text
Initial → Resolving → Resolved
Resolving → Failure → Retry → Resolving
```

Failed identification does **not** replace an already selected machine.

## Security

* JWT only via centralized Bearer attachment.
* Google `id_token` is never sent to machine endpoints.
* Machine context is in-memory only (not authority, not SecureStorage).
* No client-supplied `tenant_id` on resolve.

## Related

* [OPERATOR_BOOTSTRAP.md](OPERATOR_BOOTSTRAP.md)
* [ADR-005](adr/ADR-005-machine-identification.md)
* [Mobile API Contract](nexovending_API/Mobile_API_Contract_NexoVending.md)
