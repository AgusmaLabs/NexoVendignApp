# VendingApp Authentication

## Current flow

```text
Google Sign-In
      ↓
id_token
      ↓
NexoVending /auth/session
      ↓
Session JWT
      ↓
SecureStorage
      ↓
GET /operators/me
      ↓
Vending Operator
      ↓
Machine / Replenishment / Product Lookup
```

Product lookup (and later replenishment lines) use the Session JWT only:

```text
Google
  ↓
Session JWT
  ↓
ApiClient
  ↓
Product Lookup
```

Google `id_token` is never sent to product endpoints.

| Commit | Meaning |
| ------ | ------- |
| Commit 3 | Google identity (`id_token` in memory) |
| Commit 4 | NexoVending session (Session JWT + SecureStorage) |
| Commit 5 | Operator bootstrap (`/operators/me`) |

`Authenticated` means a non-expired Session JWT exists. The operational shell
requires a successful operator bootstrap (`OperatorBootstrapLoaded`).

## Architecture

* `GoogleSignInService` isolates the official `google_sign_in` SDK.
* `SessionService` exchanges `id_token` + `tenant_id` for a Session JWT.
* `OperatorService` loads the Vending operator via authenticated ApiClient.
* `AuthGate` routes: login → bootstrap → welcome shell.
* UI never displays `id_token` or Session JWT values.

## Configuration

```bash
flutter run \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=your-web-client-id.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=your-ios-client-id.apps.googleusercontent.com \
  --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=TENANT_ID=tenant-a
```

See platform setup details in prior sections of this document and
[SESSION.md](SESSION.md) / [OPERATOR_BOOTSTRAP.md](OPERATOR_BOOTSTRAP.md).

## Security

* Never log `id_token`, Session JWT, or authorization headers.
* Do not write the Google `id_token` to storage.
* Persist only the NexoVending Session JWT via `SecureStorage`.
* Operator context is not authority for authorization.

## Related

* [SESSION.md](SESSION.md)
* [OPERATOR_BOOTSTRAP.md](OPERATOR_BOOTSTRAP.md)
* [PRODUCT_LOOKUP.md](PRODUCT_LOOKUP.md)
* [ADR-002](adr/ADR-002-google-sign-in-boundary.md)
* [ADR-003](adr/ADR-003-session-token-storage.md)
* [ADR-004](adr/ADR-004-operator-bootstrap.md)
* [Networking](NETWORKING.md)
* [Architecture](architecture.md)
