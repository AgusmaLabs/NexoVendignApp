# Operator Bootstrap

## Purpose

After a valid NexoVending Session JWT exists, VendingApp resolves the
**Vending operator** identity required for field operations.

```text
The mobile application does not determine who the Vending operator is.
NexoVending is the authority for the Vending operator identity.
```

## Endpoint

```http
GET /api/v1/operators/me
Authorization: Bearer <session-jwt>
```

Uses the shared authenticated `ApiClient` from Commit 4. Features must not
build Authorization headers manually.

## Session → Operator

```text
Session
  └── authenticated JWT

Operator
  └── business identity in NexoVending
```

```text
Session ≠ Operator
Valid JWT ≠ Valid Vending Operator
```

## Data model

Maps NexoVending `OperatorOut`:

| Field | Required |
| ----- | -------- |
| `operator_id` | yes |
| `tenant_id` | yes |
| `role` | yes |
| `status` | yes |
| `provider` | yes |
| `subject` | yes |
| `display_name` | optional |
| `email` | optional |

## Bootstrap flow

```text
Google Sign-In
      ↓
POST /auth/session
      ↓
Session JWT
      ↓
GET /operators/me
      ↓
Operator context
      ↓
Application shell
```

Triggered automatically after session create/restore via
`AuthenticationController.afterSessionEstablished`.

## States

| State | UI |
| ----- | -- |
| Unknown | (before load) |
| Loading | `Cargando operador...` |
| Loaded | `Bienvenido, <name>` shell |
| AccessDenied | access denied message |
| NotConfigured | operator not configured |
| Failure | message + `Reintentar` |
| SessionExpired | return to login |

## Errors

| HTTP | App handling |
| ---- | ------------ |
| 401 | Clear session → authentication flow |
| 403 + `OPERATOR_NOT_FOUND` | Not configured |
| 403 (other) | Access denied |
| 404 | Not configured |
| 5xx / network / timeout | Failure + retry |

## Restoration

On startup: restore Session JWT → if valid → `GET /operators/me`.
Operator is **not** treated as local authority; always re-fetched from API.

## Logout

Clears Session JWT (SecureStorage) and in-memory operator context.

## Security

* JWT stays in SecureStorage only.
* Google `id_token` is never sent to `/operators/me`.
* Operator payload must not include tokens.
* Logs must not contain Authorization / JWT values.

## Testing

```bash
flutter test test/features/operator
```

## Related

* [AUTHENTICATION.md](AUTHENTICATION.md)
* [SESSION.md](SESSION.md)
* [ADR-004](adr/ADR-004-operator-bootstrap.md)
