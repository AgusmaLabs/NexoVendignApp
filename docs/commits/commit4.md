# Commit 4 — Vending Session

## Commit

```text
feat(mobile): implement Vending session
```

## Objetivo

Implementar el intercambio entre la identidad obtenida mediante Google Sign-In y la sesión autenticada de NexoVending.

El flujo implementado será:

```text
Google Sign-In
      │
      ▼
   id_token
      │
      ▼
POST /api/v1/auth/session
      │
      ▼
NexoVending
      │
      ▼
access_token (Session JWT)
      │
      ▼
SecureStorage
      │
      ▼
Authenticated Session
```

Este commit convierte el resultado del Commit 3 en una **sesión válida de VendingApp contra NexoVending**.

La aplicación todavía **no implementa el bootstrap del operador mediante `/operators/me`**. Eso corresponde al Commit 5.

---

# 1. Alcance

## Incluye

* Cliente de sesión contra NexoVending.
* `POST /api/v1/auth/session`.
* Envío del Google `id_token`.
* Envío del `tenant_id` requerido por el contrato de autenticación.
* Modelo de respuesta de sesión.
* Session JWT.
* Persistencia segura del Session JWT.
* Restauración de sesión al iniciar la aplicación.
* Expiración de sesión.
* Logout local.
* Manejo de errores de sesión.
* Inyección de dependencias.
* Estado global de sesión.
* Tests unitarios.
* Tests de integración HTTP.
* Tests de widget.
* Tests de persistencia segura.
* Documentación de autenticación y sesión.

## No incluye

* `/operators/me`.
* Resolución de operador.
* Autorización de operador.
* Permisos de Vending.
* Roles de Vending.
* Machine API.
* Product API.
* Replenishment API.
* QR.
* Barcode.
* GPS.
* Offline synchronization.
* Refresh token si el contrato actual no lo contempla.
* Acceso directo a Nexo Platform.

---

# 2. Contrato de sesión

El endpoint utilizado es:

```http
POST /api/v1/auth/session
```

Request conceptual:

```json
{
  "id_token": "<google-id-token>",
  "tenant_id": "<tenant-id>"
}
```

Response conceptual:

```json
{
  "access_token": "<session-jwt>",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

Los nombres y campos definitivos deben respetar exactamente el **Mobile Authentication Contract de NexoVending**.

VendingApp no debe inventar ni reinterpretar el contrato HTTP.

---

# 3. Session Architecture

La responsabilidad queda separada así:

```text
┌───────────────────────┐
│   Authentication UI   │
└───────────┬───────────┘
            │
            ▼
┌───────────────────────┐
│ SessionController     │
└───────────┬───────────┘
            │
            ▼
┌───────────────────────┐
│ SessionService        │
└───────────┬───────────┘
            │
            ▼
┌───────────────────────┐
│ ApiClient             │
└───────────┬───────────┘
            │
            ▼
     NexoVending API
```

La persistencia queda separada:

```text
SessionService
      │
      ▼
SecureStorage
```

---

# 4. SessionService

Crear una abstracción:

```text
lib/core/authentication/session_service.dart
```

Responsabilidades:

* crear sesión;
* recuperar sesión;
* eliminar sesión;
* determinar si existe una sesión local válida;
* exponer información mínima de sesión.

Conceptualmente:

```text
SessionService
├── createSession(...)
├── restoreSession()
├── currentSession
└── clearSession()
```

La implementación no debe contener UI.

---

# 5. Session Model

Crear:

```text
Session
```

Debe representar la sesión emitida por NexoVending.

Como mínimo debe conservar:

```text
accessToken
tokenType
expiresIn
```

También puede almacenar información derivada necesaria para controlar la expiración local.

No debe almacenar:

* Google password;
* Google credentials;
* `id_token` después del intercambio;
* secretos innecesarios.

---

# 6. Session Creation

El flujo será:

```text
GoogleAuthenticationResult
          │
          ▼
SessionService.createSession()
          │
          ├── id_token
          └── tenant_id
          │
          ▼
POST /api/v1/auth/session
          │
          ▼
Session
```

El `id_token` obtenido en Commit 3 debe utilizarse únicamente para iniciar la sesión.

Después del intercambio exitoso, VendingApp debe conservar la sesión de NexoVending, no el `id_token` de Google.

---

# 7. Tenant Context

El endpoint `/auth/session` requiere `tenant_id`.

En este commit debe implementarse únicamente el mecanismo necesario para proporcionar ese valor al proceso de creación de sesión.

Debe quedar explícitamente separado:

```text
tenant_id utilizado para crear sesión
```

de:

```text
tenant authority de la sesión JWT
```

Después de la respuesta de NexoVending, la sesión emitida por backend es la autoridad para las llamadas posteriores.

No confiar en un `tenant_id` enviado por el usuario para llamadas de negocio.

Este commit **no implementa todavía selección de tenant ni resolución de operador**.

Si el producto V1 tiene un tenant conocido por configuración/entorno o por el flujo de acceso ya definido, debe utilizarse ese mecanismo. No inventar un selector de tenant en este commit.

---

# 8. Authorization Header

Una vez almacenada la sesión, el `ApiClient` debe poder utilizar:

```http
Authorization: Bearer <session-jwt>
```

en las llamadas autenticadas.

La incorporación debe realizarse mediante una abstracción de credenciales/sesión, no mediante headers hardcodeados dentro de cada feature.

Conceptualmente:

```text
ApiClient
   │
   ▼
SessionCredentialProvider
   │
   ▼
SecureStorage / Session
   │
   ▼
Authorization: Bearer ...
```

No agregar todavía `X-Tenant-Id` automáticamente a todas las requests.

Según el contrato actual, `X-Tenant-Id` es opcional para sesiones JWT y, si se envía, debe coincidir con el tenant contenido en la sesión.

---

# 9. SecureStorage

Utilizar la abstracción creada en Commit 2:

```text
SecureStorage
```

para almacenar el Session JWT.

Debe persistirse únicamente la información necesaria para restaurar la sesión.

Nunca almacenar el Session JWT en:

```text
LocalStorage
SharedPreferences
plain text files
logs
debug output
```

La implementación concreta debe utilizar almacenamiento seguro proporcionado por la plataforma.

---

# 10. Session Restoration

Al iniciar VendingApp:

```text
Application startup
       │
       ▼
SessionService.restoreSession()
       │
       ├── no session
       │      ↓
       │  Unauthenticated
       │
       └── valid session
              ↓
        Authenticated
```

La restauración no debe llamar todavía a `/operators/me`.

Por lo tanto, en este commit:

```text
Session JWT exists
```

significa:

> VendingApp posee una sesión local que todavía no ha sido validada mediante el bootstrap del operador.

La validación operacional ocurrirá en Commit 5.

---

# 11. Session Expiration

La aplicación debe poder determinar si una sesión local está expirada.

Si el contrato proporciona:

```text
expires_in
```

debe utilizarse para calcular la expiración local.

No implementar todavía refresh automático si el contrato de NexoVending no define refresh tokens.

Una sesión expirada debe conducir a:

```text
Authenticated
      ↓
Session expired
      ↓
Unauthenticated
```

y el token debe eliminarse del almacenamiento seguro.

---

# 12. Logout

Implementar logout local.

El flujo mínimo:

```text
User logout
    ↓
SessionService.clearSession()
    ↓
SecureStorage.remove(...)
    ↓
Unauthenticated
```

Si Google Sign-In mantiene una cuenta autenticada, el comportamiento del proveedor Google debe respetar la separación:

```text
Vending session logout
```

no necesariamente significa:

```text
Google account logout
```

No implementar logout remoto de NexoVending si el contrato no lo define.

---

# 13. Session State

Crear estados:

```text
Unauthenticated
CreatingSession
Authenticated
RestoringSession
SessionExpired
SessionFailure
```

La aplicación debe distinguir claramente:

```text
Google authentication
```

de:

```text
NexoVending session
```

Por ejemplo:

```text
Google authenticated
        ↓
Creating Vending session
        ↓
Vending session authenticated
```

Una cuenta Google autenticada por sí sola **no implica acceso autorizado a Vending**.

---

# 14. Authentication Flow

Actualizar el flujo del Commit 3:

```text
┌──────────────────┐
│ Google Sign-In   │
└────────┬─────────┘
         │
         ▼
      id_token
         │
         ▼
┌──────────────────────┐
│ POST /auth/session   │
└────────┬─────────────┘
         │
         ▼
    Session JWT
         │
         ▼
    SecureStorage
         │
         ▼
  Authenticated
```

Todavía no:

```text
Authenticated
      ↓
/operators/me
```

porque eso pertenece al Commit 5.

---

# 15. Authentication UI

Actualizar la pantalla de autenticación.

Estados:

```text
Unauthenticated
```

→ mostrar:

```text
Continuar con Google
```

Durante creación de sesión:

```text
CreatingSession
```

→ mostrar:

```text
Iniciando sesión...
```

En error:

```text
SessionFailure
```

→ mostrar mensaje amigable.

No mostrar:

* JWT;
* `id_token`;
* detalles internos del backend;
* stack traces.

---

# 16. Error Mapping

El flujo debe diferenciar errores de Google de errores de sesión.

Ejemplos:

```text
Google Sign-In cancelled
        ↓
AuthenticationCancelled
```

mientras:

```text
POST /auth/session
        ↓
401
        ↓
SessionAuthenticationFailed
```

y:

```text
POST /auth/session
        ↓
403
        ↓
SessionAccessDenied
```

y:

```text
network timeout
        ↓
SessionNetworkFailure
```

Los errores deben utilizar las abstracciones creadas en Commit 2.

---

# 17. API Client Authentication Support

Extender `ApiClient` para permitir requests autenticadas.

Debe ser posible hacer:

```text
ApiClient.authenticated()
```

o un mecanismo equivalente.

La implementación debe obtener las credenciales desde una abstracción central.

No permitir:

```text
ApiClient.get(
    ...,
    headers: {
      "Authorization": "Bearer ..."
    }
)
```

repetido manualmente en cada feature.

El objetivo es centralizar el comportamiento.

---

# 18. Dependency Injection

Actualizar el composition root:

```text
main
 │
 ├── AppConfig
 ├── Logger
 ├── Storage
 ├── ApiClient
 ├── GoogleSignInService
 ├── SessionService
 └── AuthenticationController
```

La implementación concreta de `SessionService` debe recibir:

```text
ApiClient
SecureStorage
Logger
Clock
```

cuando corresponda.

El `Clock` debe ser inyectable para poder probar expiraciones determinísticamente.

---

# 19. Tests Unitarios

## 19.1 SessionService

Probar:

* creación exitosa de sesión;
* respuesta válida;
* persistencia del token;
* restauración;
* sesión inexistente;
* sesión expirada;
* eliminación;
* logout.

---

## 19.2 Session Creation

Validar que:

```text
id_token
tenant_id
```

son enviados correctamente a `/auth/session`.

Probar que una respuesta:

```json
{
  "access_token": "token",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

produce un `Session` válido.

---

## 19.3 SecureStorage

Probar:

```text
create session
    ↓
SecureStorage.write
```

y:

```text
logout
    ↓
SecureStorage.remove
```

Validar que el token no termina en `LocalStorage`.

---

# 20. Expiration Tests

Utilizar un `FakeClock`.

Probar:

```text
now
 │
 ├── session valid
 │
 ▼
before expiration
 │
 ▼
Authenticated
```

y:

```text
after expiration
 │
 ▼
SessionExpired
 │
 ▼
SecureStorage cleared
```

También probar los límites exactos de expiración.

---

# 21. ApiClient Authentication Tests

Probar que una sesión disponible produce:

```http
Authorization: Bearer test-session-token
```

y que sin sesión:

```text
Authorization header
```

no se agrega.

Validar que:

* token correcto;
* esquema Bearer;
* no se duplica el header;
* token no aparece en logs.

---

# 22. HTTP Integration Tests

Utilizar un servidor HTTP de prueba.

Probar:

```text
VendingApp
   ↓
SessionService
   ↓
ApiClient
   ↓
POST /api/v1/auth/session
   ↓
fake backend
   ↓
Session response
```

Casos:

* 200;
* 400;
* 401;
* 403;
* 422;
* 500;
* timeout;
* network failure;
* malformed response.

No utilizar NexoVending productivo.

---

# 23. Authentication Widget Tests

Probar:

### Google success + session success

```text
Unauthenticated
      ↓
Google Sign-In
      ↓
CreatingSession
      ↓
Authenticated
```

### Google cancellation

```text
Unauthenticated
      ↓
Google Sign-In
      ↓
cancelled
      ↓
Unauthenticated
```

### Session failure

```text
Google authentication
      ↓
POST /auth/session
      ↓
error
      ↓
SessionFailure
```

### Session restoration

```text
App startup
      ↓
RestoringSession
      ↓
Authenticated
```

### Expired session

```text
App startup
      ↓
expired session
      ↓
Unauthenticated
```

---

# 24. Security Tests

Validar explícitamente que:

* Session JWT nunca aparece en logs;
* Google `id_token` nunca aparece en logs;
* Session JWT no aparece en UI;
* Session JWT no se almacena en LocalStorage;
* Session JWT se almacena únicamente mediante SecureStorage;
* errores HTTP no imprimen credenciales;
* `Authorization` header no se incluye en logs.

---

# 25. Regression Tests

Todos los tests de commits anteriores deben continuar pasando:

```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed .
```

No debe romperse:

* AppConfig;
* Router;
* Theme;
* ApiClient;
* Logger;
* Storage;
* Device abstractions;
* GoogleSignInService.

---

# 26. Documentation

Actualizar:

```text
README.md
docs/ARCHITECTURE.md
docs/AUTHENTICATION.md
docs/NETWORKING.md
```

Agregar:

```text
docs/SESSION.md
```

y actualizar:

```text
docs/adr/ADR-002-google-sign-in-boundary.md
```

para reflejar la segunda etapa del flujo.

Agregar un nuevo ADR:

```text
docs/adr/ADR-003-session-token-storage.md
```

---

# 27. SESSION.md

Documentar:

## Session creation

```text
Google id_token
      ↓
POST /api/v1/auth/session
      ↓
Session JWT
```

## Session storage

```text
Session JWT
      ↓
SecureStorage
```

## Session restoration

```text
Application startup
      ↓
SecureStorage
      ↓
Session validation by expiration
```

## Session expiration

Documentar el comportamiento esperado.

## Logout

Documentar que el logout de VendingApp elimina la sesión local.

## Important distinction

Dejar explícito:

```text
Google authentication ≠ Vending authorization
```

y:

```text
Vending session ≠ Operator bootstrap
```

El último paso será responsabilidad del Commit 5.

---

# 28. AUTHENTICATION.md

Actualizar el documento anterior para reflejar el flujo completo hasta Commit 4:

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
Authenticated Session
```

También documentar:

```text
Commit 3
Google identity

Commit 4
NexoVending session

Commit 5
Operator bootstrap
```

---

# 29. ADR-003 — Session Token Storage

Crear:

```markdown
# ADR-003: Session Token Storage

- Status: Accepted
- Date: 2026-09-15

## Context

VendingApp recibe un Session JWT desde NexoVending después de completar
el flujo de autenticación.

El token debe sobrevivir al reinicio de la aplicación sin quedar
expuesto mediante almacenamiento común o logs.

## Decision

El Session JWT será almacenado exclusivamente mediante la abstracción
SecureStorage.

VendingApp no almacenará el Session JWT en:

- LocalStorage;
- SharedPreferences;
- archivos de texto;
- bases de datos locales no cifradas;
- logs.

## Lifecycle

Google id_token
    ↓
POST /api/v1/auth/session
    ↓
Session JWT
    ↓
SecureStorage
    ↓
restore on startup
    ↓
Authenticated session

## Consequences

- La sesión puede sobrevivir al reinicio de la aplicación.
- El token queda aislado del almacenamiento general.
- La infraestructura puede utilizar Keychain/Keystore u otro mecanismo
  seguro de plataforma.
- Los tests pueden utilizar una implementación fake de SecureStorage.

## Security

El Session JWT nunca debe aparecer en:

- logs;
- mensajes de error;
- UI;
- analytics;
- crash reports.
```

---

# 30. Criterios de aceptación

## CA-01 — Session endpoint

VendingApp consume:

```http
POST /api/v1/auth/session
```

utilizando el contrato vigente de NexoVending.

## CA-02 — Google token

El `id_token` obtenido en Commit 3 es utilizado para crear la sesión.

## CA-03 — Tenant

El `tenant_id` requerido por `/auth/session` es proporcionado según el mecanismo definido por el producto.

## CA-04 — Session model

La respuesta del backend se transforma a un modelo `Session`.

## CA-05 — Secure storage

El Session JWT se almacena exclusivamente mediante `SecureStorage`.

## CA-06 — Authorization

Las requests autenticadas pueden utilizar:

```http
Authorization: Bearer <session-jwt>
```

mediante el `ApiClient` centralizado.

## CA-07 — Restoration

VendingApp puede restaurar una sesión válida después de reiniciar la aplicación.

## CA-08 — Expiration

Una sesión expirada no puede permanecer en estado `Authenticated`.

## CA-09 — Logout

Logout elimina la sesión local de `SecureStorage`.

## CA-10 — Error handling

Se diferencian:

* cancelación de Google;
* fallo de creación de sesión;
* acceso denegado;
* error de red;
* timeout;
* sesión expirada.

## CA-11 — Security

No se registran ni muestran:

* Google `id_token`;
* Session JWT;
* Authorization header.

## CA-12 — Testability

SessionService, SecureStorage, Clock y GoogleSignInService pueden reemplazarse por implementaciones fake.

## CA-13 — Integration

Existe al menos un test de integración del flujo:

```text
Google result
    ↓
SessionService
    ↓
ApiClient
    ↓
/auth/session
    ↓
Session
    ↓
SecureStorage
```

## CA-14 — Regression

Los tests de Commits 1–3 continúan pasando.

## CA-15 — CI

El pipeline completo pasa:

```text
format
analyze
test
```

## CA-16 — Documentation

La arquitectura y documentación de autenticación reflejan correctamente:

```text
Google identity
      ↓
NexoVending session
      ↓
Session JWT
      ↓
SecureStorage
```

---

# 31. Definition of Done

El Commit 4 está terminado cuando:

* [ ] `SessionService` implementado.
* [ ] `Session` model implementado.
* [ ] `/api/v1/auth/session` integrado.
* [ ] Google `id_token` enviado correctamente.
* [ ] `tenant_id` enviado según contrato.
* [ ] Session JWT recibido.
* [ ] Session JWT almacenado mediante `SecureStorage`.
* [ ] Restauración de sesión implementada.
* [ ] Expiración implementada.
* [ ] Logout local implementado.
* [ ] Estado de sesión implementado.
* [ ] `ApiClient` soporta requests autenticadas.
* [ ] `Authorization: Bearer` centralizado.
* [ ] No se almacenan tokens en LocalStorage.
* [ ] No se registran tokens.
* [ ] Tests de SessionService implementados.
* [ ] Tests de expiración implementados.
* [ ] Tests de SecureStorage implementados.
* [ ] Tests de ApiClient autenticado implementados.
* [ ] HTTP integration tests implementados.
* [ ] Widget tests implementados.
* [ ] Security tests implementados.
* [ ] Tests de Commits 1–3 continúan pasando.
* [ ] `flutter test` pasa.
* [ ] `flutter analyze` pasa.
* [ ] `dart format` pasa.
* [ ] CI pasa.
* [ ] `SESSION.md` creado.
* [ ] `AUTHENTICATION.md` actualizado.
* [ ] `NETWORKING.md` actualizado.
* [ ] `ARCHITECTURE.md` actualizado.
* [ ] ADR-002 actualizado.
* [ ] ADR-003 creado.
* [ ] No existe `/operators/me`.
* [ ] No existe resolución de Operator.
* [ ] No existe autorización de Vending.
* [ ] No existe lógica de máquinas/reposiciones.

---

# 32. Resultado esperado

Al finalizar este commit, el flujo de identidad será:

```text
                    ┌───────────────┐
                    │ Google        │
                    │ Sign-In       │
                    └───────┬───────┘
                            │
                            │ id_token
                            ▼
                    ┌───────────────┐
                    │ VendingApp    │
                    │ Session       │
                    └───────┬───────┘
                            │
                            │ POST /auth/session
                            ▼
                    ┌───────────────┐
                    │ NexoVending   │
                    │ API           │
                    └───────┬───────┘
                            │
                            │ Session JWT
                            ▼
                    ┌───────────────┐
                    │ SecureStorage │
                    └───────┬───────┘
                            │
                            ▼
                    Authenticated
                    Vending Session
```

Pero todavía **no se considera que el operador esté listo para trabajar**.

El siguiente paso será:

```text
Session JWT
     ↓
GET /api/v1/operators/me
     ↓
Vending Operator
     ↓
Operator Bootstrap
```

Eso corresponde al **Commit 5**.
