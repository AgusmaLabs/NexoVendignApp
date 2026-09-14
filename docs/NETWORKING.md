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

Non-responsibilities:

* authentication / session JWT attachment;
* authorization decisions;
* tenant selection;
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
* `SecureStorage` is prepared for later session persistence; Commit 2 does not
  store authentication material.
* Authorization headers are intentionally not attached yet.

## Configuration

```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=HTTP_TIMEOUT_MS=30000
```
