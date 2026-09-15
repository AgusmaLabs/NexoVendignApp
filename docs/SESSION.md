# VendingApp Session

## Session creation

```text
Google id_token
      ↓
POST /api/v1/auth/session
      ↓
Session JWT
```

Request (Mobile Authentication Contract):

```json
{
  "id_token": "<google-id-token>",
  "tenant_id": "<tenant-id>"
}
```

Response:

```json
{
  "access_token": "<session-jwt>",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

`tenant_id` for session creation comes from `AppConfig.tenantId`
(`TENANT_ID` dart-define). After NexoVending issues the JWT, that session
is the authority for later authenticated calls — not a client-supplied
tenant header.

## Session storage

```text
Session JWT
      ↓
SecureStorage
```

Only the Session JWT (and metadata needed to restore expiration) is
persisted via `FlutterSecureStorageAdapter` (Keychain / Keystore).
Tests use `MemorySecureStorage`. The Google `id_token` is not stored
after the exchange.

Never store the Session JWT in `LocalStorage`, SharedPreferences, plain
files, or logs.

## Session restoration

```text
Application startup
      ↓
SecureStorage
      ↓
Session validation by expiration
```

Restoration does **not** call `/operators/me` (Commit 5).

## Session expiration

`Session.expiresAt` is derived from `expires_in` at issuance (or restored
from persisted `expires_at`). When the local clock reaches `expiresAt`,
`SessionService` treats the session as invalid and authenticated API
calls no longer attach `Authorization`.

## Logout

Logout clears the local Session JWT from `SecureStorage` and returns the
UI to `Unauthenticated`. It does not require Google account logout.

## Authorization header

Authenticated `ApiClient` requests attach:

```http
Authorization: Bearer <session-jwt>
```

via `SessionCredentialProvider`. `X-Tenant-Id` is not auto-injected.

## Important distinction

```text
Google authentication ≠ Vending authorization
```

```text
Vending session ≠ Operator bootstrap
```

Operator bootstrap via `/operators/me` is implemented — see
[OPERATOR_BOOTSTRAP.md](OPERATOR_BOOTSTRAP.md).

## Related

* [AUTHENTICATION.md](AUTHENTICATION.md)
* [OPERATOR_BOOTSTRAP.md](OPERATOR_BOOTSTRAP.md)
* [ADR-003: Session Token Storage](adr/ADR-003-session-token-storage.md)
* [ADR-004: Operator Bootstrap](adr/ADR-004-operator-bootstrap.md)
* [Mobile Auth Contract](nexovending_API/Mobile_Auth_Contract_NexoVending.md)
