# NexoVending Mobile — Architecture

**Status:** Ready for implementation
**Client:** Flutter
**Backend:** NexoVending HTTP API v1
**Authentication:** Nexo Platform 1.11.0 Session JWT
**Architecture decision:** Mobile → NexoVending public HTTP API

---

# 1. Propósito

Este documento define la arquitectura técnica de NexoVending Mobile.

La aplicación móvil es un **cliente externo de NexoVending**.

No es una extensión del dominio Vending y no accede directamente a:

* PostgreSQL;
* repositorios;
* Platform internals;
* UoW;
* Outbox;
* adapters internos;
* entidades persistentes.

La dependencia arquitectónica es:

```text
NexoVending Mobile
        │
        │ HTTPS / JSON
        ▼
NexoVending HTTP API
        │
        ▼
NexoVending Application
        │
        ▼
NexoVending Domain
        │
        ▼
Nexo Platform
```

Nunca:

```text
Flutter
   │
   └──► Nexo Platform internals
```

---

# 2. Principio arquitectónico

> **Flutter captura y presenta. NexoVending decide y persiste.**

Flutter puede:

* capturar QR;
* capturar barcode;
* capturar GPS;
* capturar cantidades;
* seleccionar slots;
* presentar errores;
* mantener estado temporal;
* persistir credenciales de forma segura;
* persistir idempotency keys.

Flutter no puede ser autoridad sobre:

* tenant;
* Operator;
* permisos;
* asignaciones;
* stock;
* capacidad;
* sustituciones;
* estado de reposición;
* inventario;
* producto definitivo.

---

# 3. Monolito fachada

La arquitectura actual utiliza un único host Vending:

```text
                     ┌──────────────────────┐
                     │      Flutter         │
                     └──────────┬───────────┘
                                │
                         HTTPS / JSON
                                │
                                ▼
                     ┌──────────────────────┐
                     │  NexoVending API     │
                     │                      │
                     │  /auth/session       │
                     │  /operators/me       │
                     │  /machines/...       │
                     │  /products/...       │
                     │  /replenishments/... │
                     └──────────┬───────────┘
                                │
                     ┌──────────┴──────────┐
                     │                     │
                     ▼                     ▼
             Vending Application     Platform Auth
                     │                     │
                     ▼                     ▼
             Vending Domain        Session JWT
                     │
                     ▼
              Nexo Platform
```

El endpoint:

```text
POST /api/v1/auth/session
```

es una **fachada de producto** sobre capacidades de autenticación de Platform.

Esto permite que Mobile conozca un único host.

---

# 4. Authentication architecture

## 4.1 Flujo

```text
Flutter
  │
  │ Google Sign-In
  ▼
Google id_token
  │
  │ POST /auth/session
  ▼
NexoVending HTTP
  │
  ├── AuthenticationProvider.authenticate
  │
  ├── ResolveOperator
  │
  └── Platform JwtService.issue_session
              │
              ▼
       Session JWT
              │
              ▼
           Flutter
              │
              │ Bearer JWT
              ▼
       Business endpoints
```

---

# 5. Ownership de autenticación

| Capa                | Responsabilidad          |
| ------------------- | ------------------------ |
| Flutter             | Google Sign-In SDK       |
| Vending API         | Session facade           |
| Platform            | AuthenticationProvider   |
| Platform            | JWT issuance/decoding    |
| Platform            | Cryptographic operations |
| Vending Application | ResolveOperator          |
| Vending Domain      | Operator authorization   |
| Flutter             | Secure token storage     |

El dominio Vending no debe importar SDKs de Google ni librerías JWT para implementar autenticación propia.

La integración `GoogleOAuthProvider` debe permanecer en el punto de composición HTTP definido por Vending.

---

# 6. Session JWT

El JWT de sesión es emitido por Platform.

La sesión contiene el contexto de tenant:

```text
SessionToken
   │
   └── tenant_id
```

Para una llamada de negocio:

```http
Authorization: Bearer <jwt>
```

es suficiente para determinar el tenant de la sesión.

Opcionalmente:

```http
X-Tenant-Id: <same-tenant>
```

puede enviarse como consistency check.

Nunca:

```json
{
  "tenant_id": "..."
}
```

debe utilizarse como autoridad en un endpoint de negocio.

---

# 7. Harness authentication

Los tests/CI pueden utilizar:

```http
Authorization: Bearer principal/google/<subject>
X-Tenant-Id: <tenant>
```

Este mecanismo existe para harness/trusted test scenarios.

Flutter production no debe generar este formato.

---

# 8. Operator resolution

La identidad autenticada no equivale automáticamente al Operator Vending.

La resolución es:

```text
Session / Principal
       │
       ▼
tenant context
       │
       ▼
ResolveOperator
       │
       ▼
Vending Operator
```

El Operator debe:

* existir;
* pertenecer al tenant;
* estar activo;
* tener el rol apropiado;
* cumplir las políticas Vending.

Los roles genéricos del JWT no sustituyen a `OperatorRole`.

---

# 9. `/operators/me`

Después de autenticarse:

```http
GET /api/v1/operators/me
```

sirve como bootstrap del contexto operativo.

La aplicación puede obtener:

* identidad operativa;
* información del Operator;
* estado;
* contexto necesario para la UX.

Mobile no debe reconstruir esta información a partir de claims JWT.

---

# 10. API boundary

El cliente consume exclusivamente:

```text
/api/v1/*
```

Ejemplos:

```text
POST /api/v1/auth/session
GET  /api/v1/operators/me

GET  /api/v1/machines/resolve
GET  /api/v1/machines/{id}
GET  /api/v1/machines/{id}/slots

GET  /api/v1/products/barcode/{barcode}

POST /api/v1/replenishments
GET  /api/v1/replenishments/{id}
POST /api/v1/replenishments/{id}/lines
POST /api/v1/replenishments/{id}/complete
POST /api/v1/replenishments/{id}/cancel
```

Mobile no consume endpoints internos de Platform.

---

# 11. Machine boundary

La máquina es resuelta por:

```text
GET /machines/resolve
```

La aplicación no mantiene una autoridad local sobre máquinas.

El backend determina:

```text
machine exists?
operator has access?
machine active?
tenant correct?
```

---

# 12. Slot architecture

Un slot representa:

> posición/contenedor físico configurable.

No representa:

> SKU permanente.

Modelo conceptual:

```text
Machine
  │
  ├── Slot
  │    ├── capacity
  │    ├── status
  │    ├── preferred_product
  │    └── selling_price
  │
  └── Slot
```

La configuración:

```text
preferred_product_id
```

no determina necesariamente el producto que será cargado.

La línea de reposición contiene:

```text
actual product loaded
```

Por lo tanto:

```text
MachineSlot.preferred_product
        ≠
ReplenishmentLine.product
```

salvo que coincidan en una operación concreta.

---

# 13. Replenishment architecture

La visita sigue:

```text
CREATED
   ↓
IN_PROGRESS
   ↓
lines
   ↓
COMPLETED
```

o:

```text
IN_PROGRESS
   ↓
CANCELLED
```

Mobile nunca modifica directamente el estado local como autoridad.

El servidor es la fuente de verdad.

---

# 14. GPS architecture

Flutter utiliza una abstracción:

```text
LocationService
```

para obtener:

```text
latitude
longitude
accuracy
timestamp
```

La aplicación envía la ubicación al backend.

En V1:

```text
GPS
 ↓
stored
 ↓
audit
```

No:

```text
GPS
 ↓
geofence
 ↓
authorization
```

El geofencing está fuera de alcance.

---

# 15. Product lookup

Flutter utiliza:

```text
BarcodeScanner
      │
      ▼
barcode
      │
      ▼
GET /products/barcode/{barcode}
```

Resultado:

```text
200 → RESOLVED
404 → UNKNOWN
```

Nunca:

```text
404
 ↓
create Product
```

---

# 16. Unresolved product architecture

Cuando el producto no puede ser identificado:

```text
Barcode unknown
       │
       ▼
manual_description
       │
       ▼
ReplenishmentLine
       │
       └── PENDING_PRODUCT_RESOLUTION
```

Modelo conceptual:

```text
ReplenishmentLine
├── slot_id
├── quantity
├── product_id = null
├── manual_description
└── resolution_status = PENDING
```

El Mobile conserva la evidencia operacional.

No inventa identidad de catálogo.

---

# 17. Deferred inventory

La arquitectura mantiene una separación estricta:

```text
PENDING line
     │
     └── no InventoryMovement
```

Después:

```text
Admin
  ↓
resolve product
  ↓
RESOLVED
  ↓
InventoryMovement
```

El ledger nunca recibe:

```text
product_id = null
```

---

# 18. Mixed machine layouts

La aplicación no debe implementar:

```text
if machine_type == SNACK:
    slot_required = true

if machine_type == COFFEE:
    slot_required = false
```

como regla arquitectónica rígida.

La existencia y configuración de slots pertenece al modelo físico de la máquina.

Por lo tanto:

```text
Machine
   ↓
Slots
   ↓
physical configuration
```

La UI debe adaptarse a los slots retornados por el backend.

Esto permite:

* snack machines;
* coffee machines;
* mixed machines;
* diferentes capacidades;
* reconfiguración física.

---

# 19. Flutter architecture

Estructura recomendada:

```text
lib/
├── app/
│   ├── bootstrap/
│   ├── router/
│   └── theme/
│
├── core/
│   ├── config/
│   ├── networking/
│   ├── authentication/
│   ├── storage/
│   ├── errors/
│   ├── logging/
│   └── device/
│
├── features/
│   ├── authentication/
│   ├── operator/
│   ├── machines/
│   ├── products/
│   └── replenishments/
│
└── shared/
```

---

# 20. Dependency direction

La dirección interna es:

```text
Presentation
      ↓
Application
      ↓
Domain
      ↓
Data
      ↓
External
```

Nunca:

```text
Domain
   ↓
Flutter widgets
```

ni:

```text
Domain
   ↓
HTTP client
```

El dominio debe permanecer independiente de Flutter.

---

# 21. Networking

El cliente HTTP debe centralizar:

* base URL;
* headers;
* Bearer token;
* request ID;
* idempotency keys;
* serialización;
* errores HTTP;
* retry policy.

Conceptualmente:

```text
ApiClient
   │
   ├── AuthInterceptor
   ├── RequestIdInterceptor
   ├── IdempotencyInterceptor
   └── ErrorMapper
```

La URL del host debe ser configurable por environment.

No hardcodear:

```text
tenant
operator
machine
access token
```

---

# 22. Authentication module

El módulo de autenticación debe separar:

```text
GoogleSignInService
        │
        ▼
SessionApi
        │
        ▼
SessionTokenStore
```

Por ejemplo:

```text
GoogleSignInService
    → id_token

SessionApi
    → access_token

SecureTokenStore
    → access_token
```

El módulo no debe implementar JWT cryptography.

---

# 23. Device abstractions

Las capacidades nativas deben estar detrás de interfaces:

```text
BarcodeScanner
LocationService
SecureStorage
ConnectivityService
```

Esto permite:

* mocks;
* tests;
* reemplazo de implementaciones;
* testing sin hardware.

---

# 24. Replenishment feature

La feature debe encapsular:

```text
presentation/
application/
domain/
data/
```

Conceptualmente:

```text
ReplenishmentScreen
       ↓
ReplenishmentController
       ↓
ReplenishmentUseCase
       ↓
ReplenishmentRepository
       ↓
NexoVending API
```

El cliente no replica reglas de dominio del backend.

---

# 25. Local persistence

V1 puede utilizar almacenamiento local para:

* Session JWT;
* preferencias;
* idempotency keys;
* estado temporal necesario para recuperación de UX.

No debe implementar un segundo ledger de inventario.

```text
Local storage
      ≠
Server ledger
```

---

# 26. Idempotency architecture

Cada operación mutable debe tener una clave estable.

```text
User action
    ↓
Operation ID
    ↓
Idempotency-Key
    ↓
HTTP request
```

Si existe retry:

```text
same operation
      ↓
same Idempotency-Key
```

Nunca generar una clave nueva automáticamente para un retry de la misma operación.

---

# 27. Error architecture

La capa HTTP transforma:

```text
HTTP response
     ↓
ApiException
     ↓
Domain/application error
     ↓
UX action
```

Ejemplo:

```text
409 CAPACITY_EXCEEDED
        ↓
CapacityExceededException
        ↓
"Reduce la cantidad o selecciona otro slot"
```

No exponer detalles internos del backend.

---

# 28. Security boundary

Mobile nunca tiene acceso directo a:

```text
PostgreSQL
Platform Database
Platform repositories
Platform UoW
Platform Outbox
Vending repositories
Vending internal services
```

Todo acceso pasa por:

```text
HTTPS
  ↓
NexoVending API
```

---

# 29. Tenant isolation

El tenant es una propiedad de seguridad del backend.

Con Session JWT:

```text
JWT
 └── tenant_id
```

Con harness:

```text
Principal + X-Tenant-Id
```

Flutter no debe construir queries ni filtros de tenant.

Nunca usar:

```text
tenant_id supplied by arbitrary JSON
```

como autoridad.

---

# 30. Authorization boundary

Platform puede determinar capacidades generales como:

```text
Permission
Entitlement
```

pero Vending determina autorización específica del dominio:

```text
Operator
MachineAssignment
ReplenishmentPolicy
```

Conceptualmente:

```text
Platform
   ↓
"who is authenticated?"

Vending
   ↓
"can this Operator perform this vending operation?"
```

---

# 31. API versioning

Mobile consume:

```text
/api/v1
```

La aplicación debe mantener:

```text
baseUrl
+
apiVersion
```

configurables.

Los contratos HTTP deben derivarse del OpenAPI del backend.

Preferir:

```text
OpenAPI
   ↓
generated/client models
```

cuando sea conveniente.

El markdown contractual continúa siendo la referencia humana.

---

# 32. Testing architecture

La aplicación debe tener:

### Unit tests

Para:

* use cases;
* state transitions;
* error mapping;
* validation local;
* idempotency key handling.

### Widget tests

Para:

* login;
* machine selection;
* slot selection;
* replenishment;
* pending product UX;
* error states.

### Integration tests

Para:

```text
Flutter
   ↓
HTTP
   ↓
NexoVending test API
```

### Contract tests

Validar que:

```text
Flutter client
      ↕
OpenAPI
      ↕
NexoVending API
```

permanezcan compatibles.

---

# 33. Backend contract tests relevantes

Mobile debe probar como mínimo:

```text
POST /auth/session
GET /operators/me

GET /machines/resolve
GET /machines/{id}/slots

GET /products/barcode/{barcode}

POST /replenishments
POST /replenishments/{id}/lines
POST /replenishments/{id}/complete
POST /replenishments/{id}/cancel
```

Y el flujo:

```text
unknown barcode
      ↓
manual description
      ↓
pending line
      ↓
complete
```

debe formar parte de la integración.

---

# 34. Offline strategy

La arquitectura prepara el cliente para:

```text
offline capture
      ↓
local queue
      ↓
retry
      ↓
idempotent API
```

pero V1 no implementa sincronización completa.

No crear:

```text
local inventory ledger
```

como sustituto del backend.

---

# 35. Observability

Cada request debe poder correlacionarse mediante:

```http
X-Request-Id
```

Cuando corresponda, Mobile puede generar un request ID.

Los errores del backend pueden retornar:

```json
{
  "error": {
    "code": "...",
    "request_id": "..."
  }
}
```

La aplicación debe conservar el `request_id` para soporte/debug cuando sea útil.

---

# 36. UX architecture principle

La UX debe representar estados reales del backend.

Ejemplo:

```text
PENDING_PRODUCT_RESOLUTION
```

no debe mostrarse como:

```text
Producto OK
```

Debe mostrarse como:

```text
Producto pendiente de catálogo
```

Esto es especialmente importante porque el inventario por SKU todavía no refleja esa línea hasta su resolución administrativa.

---

# 37. Prohibiciones arquitectónicas

Flutter no debe:

* acceder a Platform directamente;
* acceder a PostgreSQL;
* implementar JWT crypto;
* implementar Google OAuth backend;
* fabricar `product_id`;
* crear productos;
* decidir tenant;
* decidir permisos;
* decidir stock;
* decidir capacidad;
* decidir sustituciones;
* modificar inventario directamente;
* implementar un ledger paralelo;
* asumir que preferred product es actual product;
* asumir reglas rígidas por `machine_type`.

---

# 38. Estructura de datos conceptual

```text
Session
├── access_token
├── token_type
└── expires_in

Operator
├── id
├── status
└── role

Machine
├── id
├── identifier
├── type
└── slots[]

Slot
├── id
├── number
├── capacity
├── preferred_product_id
├── selling_price
└── current_quantity

Replenishment
├── id
├── machine_id
├── operator_id
├── status
├── location
└── lines[]

ReplenishmentLine
├── id
├── slot_id
├── product_id?
├── quantity
├── manual_description?
├── resolution_status
└── replacement_reason?
```

---

# 39. End-to-end architecture

```text
┌───────────────────────────────┐
│           Flutter             │
│                               │
│ Google Sign-In                │
│ BarcodeScanner                │
│ LocationService               │
│ SecureStorage                 │
│ Replenishment UX              │
└───────────────┬───────────────┘
                │
                │ HTTPS
                ▼
┌───────────────────────────────┐
│       NexoVending API         │
│                               │
│ /auth/session                 │
│ /operators/me                 │
│ /machines                     │
│ /products                     │
│ /replenishments               │
└───────────────┬───────────────┘
                │
        ┌───────┴────────┐
        ▼                ▼
┌──────────────┐  ┌───────────────┐
│ Vending      │  │ Nexo Platform │
│ Application  │  │ 1.11.0        │
│ + Domain     │  │               │
└──────┬───────┘  │ Auth/JWT/UoW  │
       │          │ Transactions  │
       │          └───────┬───────┘
       └──────────────────┤
                          ▼
                   PostgreSQL
```

---

# 40. Definition of Done

La arquitectura Mobile está correctamente implementada cuando:

```text
Flutter
   ↓
Google Sign-In
   ↓
id_token
   ↓
POST /auth/session
   ↓
Session JWT
   ↓
/operators/me
   ↓
machine resolve
   ↓
slots
   ↓
replenishment + GPS
   ↓
product lookup
   ├── resolved
   └── pending
   ↓
complete
   ↓
NexoVending
   ↓
Platform transaction / inventory
```

y se cumplen simultáneamente:

* [ ] Mobile utiliza exclusivamente la API pública de NexoVending.
* [ ] Authentication usa Session JWT de Platform 1.11.0.
* [ ] Flutter no implementa JWT crypto.
* [ ] Flutter no genera `principal/...` en producción.
* [ ] Tenant authority proviene de la sesión.
* [ ] Operator se obtiene/resuelve mediante NexoVending.
* [ ] Machine access es decidido por backend.
* [ ] Slots se tratan como posiciones físicas.
* [ ] Preferred product no se trata como SKU rígido.
* [ ] Unknown barcode puede producir PENDING.
* [ ] PENDING no crea producto.
* [ ] Complete puede contener líneas PENDING.
* [ ] Mobile no escribe inventario directamente.
* [ ] Idempotency keys sobreviven a retries.
* [ ] Errores de dominio tienen UX accionable.
* [ ] El cliente no replica reglas de negocio como autoridad.
* [ ] No existe dependencia Mobile → Platform internals.
* [ ] OpenAPI y cliente permanecen compatibles.

---

# 41. Documentos relacionados

```text
docs/
├── prd.md
├── architecture/
│   ├── ARCHITECTURE.md
│   ├── API_ARCHITECTURE.md
│   └── REPLENISHMENT_EXECUTION_CONTEXT.md
├── api/
│   ├── MOBILE_API_CONTRACT.md
│   ├── MOBILE_AUTHENTICATION_CONTRACT.md
│   └── openapi-v1.json
├── security/
│   └── OPERATOR_ACCESS_MODEL.md
└── adr/
    ├── ADR-006-platform-authentication.md
    ├── ADR-029-vending-http-api-boundary.md
    ├── ADR-033-monolith-session-facade.md
    └── ...
```
