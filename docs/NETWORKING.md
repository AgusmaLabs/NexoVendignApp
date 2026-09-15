# VendingApp Networking

## API Boundary

```text
VendingApp
    │
    │ HTTPS
    ▼
NexoVending Public API
```

VendingApp communicates exclusively with the public NexoVending HTTP API.
It does not access Nexo Platform internals, databases, or private backend APIs.

## ApiClient

`HttpApiClient` is the centralized networking entry point.

Responsibilities:

* HTTP methods (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`);
* base URL from `AppConfig.apiBaseUrl`;
* configurable timeout from `AppConfig.httpTimeout`;
* common headers;
* automatic `X-Request-Id` generation (or caller-supplied IDs);
* response capture;
* mapping transport/HTTP failures into application exceptions;
* structured logging of method, endpoint, status, request ID, and duration.

Responsibilities added in Commit 4:

* optional `authenticated: true` on requests;
* `Authorization: Bearer <session-jwt>` via `SessionCredentialProvider`
  (typically `HttpSessionService`).

Non-responsibilities:

* creating or validating sessions (owned by `SessionService`);
* authorization decisions;
* tenant selection for business calls;
* vending business rules;
* inventory rules;
* NexoVending DTO/domain models.

Feature layers own DTO mapping. The client returns a generic `ApiResponse`.

## Error handling

```text
HTTP / Network
      ↓
ApiClient
      ↓
Infrastructure Exception
      ↓
Feature/Application
```

Mapped exception types:

| Condition | Exception |
| --------- | --------- |
| Transport / connectivity failure | `NetworkException` |
| Request exceeds timeout | `TimeoutException` |
| Non-2xx HTTP status | `HttpException` (keeps status, body, request ID) |
| JSON encode/decode failure | `SerializationException` |
| Unexpected client failure | `UnknownApiException` |

Package-specific HTTP errors must not leak into features.

## Security

* Access tokens, passwords, and `id_token` values must never be logged.
* `sanitizeLogContext` strips sensitive keys from logger context maps.
* Session JWT is persisted only via `SecureStorage` (see [SESSION.md](SESSION.md)).
* Unauthenticated requests do not attach `Authorization`.
* Authenticated requests attach Bearer via `SessionCredentialProvider`.

## Configuration

```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=HTTP_TIMEOUT_MS=30000 \
  --dart-define=TENANT_ID=tenant-a
```
