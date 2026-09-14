# PRD — NexoVending Mobile V1

**Producto:** NexoVending Mobile
**Versión:** V1
**Plataforma:** Flutter
**Backend:** NexoVending HTTP API v1
**Estado:** Ready for implementation
**Backend prerequisites:** V9–V12 implemented

---

## 1. Objetivo

NexoVending Mobile es una aplicación Flutter para que operadores de reposición ejecuten y registren visitas de reposición en máquinas vending.

El objetivo de V1 es permitir que un reponedor pueda:

1. autenticarse;
2. identificar una máquina;
3. registrar ubicación GPS;
4. consultar la configuración física de la máquina;
5. identificar productos mediante barcode;
6. registrar productos conocidos;
7. registrar productos desconocidos o ilegibles mediante una línea pendiente;
8. registrar cantidades y posiciones físicas;
9. completar o cancelar una visita;
10. mantener trazabilidad e idempotencia de las operaciones.

La aplicación **captura y presenta información**.

NexoVending **valida, autoriza y decide el efecto de negocio**.

---

## 2. Principio fundamental

```text
Flutter
  │
  │ captura datos / presenta estado
  ▼
NexoVending HTTP API
  │
  │ autentica / autoriza / valida
  ▼
Application
  │
  ▼
Domain
  │
  ▼
Nexo Platform + PostgreSQL
```

El móvil nunca es autoridad para:

* tenant;
* operador;
* permisos;
* asignaciones de máquinas;
* stock;
* capacidad;
* sustituciones;
* estado de una reposición;
* movimientos de inventario;
* identidad definitiva de un producto.

---

## 3. Usuarios

### 3.1 Reponedor

Usuario principal de la aplicación.

Debe:

* existir como `Operator` en NexoVending;
* estar `ACTIVE`;
* tener rol `OPERATOR`;
* tener acceso vigente a las máquinas que opera.

### 3.2 Administrador

No es el usuario principal de la aplicación de campo.

Puede utilizar posteriormente interfaces administrativas para:

* revisar productos pendientes;
* crear productos en catálogo;
* resolver líneas pendientes;
* administrar inventario;
* administrar operadores y asignaciones.

La resolución administrativa de productos pendientes no forma parte del flujo normal del reponedor.

---

# 4. Autenticación

## 4.1 Flujo implementado

La autenticación de Mobile utiliza Google Sign-In y una sesión emitida por Platform.

```text
Flutter
  │
  ├── Google Sign-In
  │
  └── obtiene id_token
          │
          ▼
POST /api/v1/auth/session
{
  id_token,
  tenant_id
}
          │
          ▼
NexoVending fachada
          │
          ├── AuthenticationProvider.authenticate
          ├── ResolveOperator
          └── Platform JwtService.issue_session
                    │
                    ▼
          Session JWT
                    │
                    ▼
Flutter almacena access_token
```

La aplicación utiliza posteriormente:

```http
Authorization: Bearer <session-jwt>
```

en las llamadas de negocio.

---

## 4.2 Responsabilidad de cada capa

| Componente       | Responsabilidad                                      |
| ---------------- | ---------------------------------------------------- |
| Flutter          | Google Sign-In y obtención de `id_token`             |
| NexoVending HTTP | fachada `/auth/session` y resolución de Operator     |
| Nexo Platform    | OAuth provider, JWT issuance/decoding y criptografía |
| Vending Domain   | Operator y autorización de negocio                   |

El dominio Vending nunca implementa:

* Google OAuth;
* JWT signing;
* JWT verification;
* criptografía propia;
* interpretación de `roles` del JWT como `OperatorRole`.

---

## 4.3 Tenant

Para una Session JWT:

```text
session.tenant_id
       │
       ▼
tenant authority
```

`X-Tenant-Id` es opcional.

Si se envía:

```text
X-Tenant-Id == session.tenant_id
```

debe cumplirse.

Para harness/tests se utiliza:

```http
Authorization: Bearer principal/<provider>/<subject>
X-Tenant-Id: <tenant>
```

El formato `principal/...` no debe ser inventado por la aplicación en producción.

---

# 5. Bootstrap del operador

Después de obtener la sesión, Mobile puede ejecutar:

```http
GET /api/v1/operators/me
```

para obtener el contexto del operador Vending.

La aplicación debe utilizar este endpoint como bootstrap del usuario operativo.

No debe asumir que:

```text
Google identity == Vending Operator
```

La relación es resuelta por NexoVending.

---

# 6. Flujo principal de reposición

```text
Login
  │
  ▼
Operator bootstrap
  │
  ▼
Identificar máquina
  │
  ▼
Obtener slots
  │
  ▼
Crear visita
  │
  ▼
Registrar líneas
  │
  ├── producto conocido
  │
  └── producto desconocido / ilegible
          │
          ▼
       PENDING
  │
  ▼
Completar visita
```

---

# 7. Identificación de máquina

El operador puede identificar una máquina mediante:

* QR;
* identificador interno.

Endpoint:

```http
GET /api/v1/machines/resolve
```

La aplicación debe resolver primero la máquina antes de iniciar una reposición.

Si el operador no tiene acceso:

```text
403 MACHINE_ACCESS_DENIED
```

Si la máquina no existe:

```text
404 NOT_FOUND
```

La aplicación no debe inventar ni aceptar un `machine_id` arbitrario como autoridad.

---

# 8. Slots y configuración física

La máquina expone sus slots físicos mediante:

```http
GET /api/v1/machines/{machine_id}/slots
```

Un slot representa una **posición/contenedor físico**.

Puede tener:

* `slot_id`;
* número;
* capacidad;
* estado;
* producto preferido;
* precio de venta;
* cantidad actual.

El producto preferido es configuración.

El producto registrado en una línea de reposición es el producto realmente cargado.

```text
MachineSlot
   │
   ├── preferred_product
   └── physical capacity

ReplenishmentLine
   │
   └── actual product loaded
```

El Mobile no debe interpretar `preferred_product_id` como un SKU obligatorio.

---

# 9. Registro de ubicación

Al iniciar una reposición:

```http
POST /api/v1/replenishments
```

Mobile envía:

```json
{
  "machine_id": "...",
  "location": {
    "latitude": -35.4264,
    "longitude": -71.6554,
    "accuracy_m": 12.4
  }
}
```

La ubicación:

* se captura;
* se almacena;
* queda asociada a la visita.

En V1:

* no existe geofencing;
* no se rechaza una visita por distancia;
* la ubicación no debe considerarse una autorización.

---

# 10. Productos

## 10.1 Producto conocido

Mobile escanea barcode:

```http
GET /api/v1/products/barcode/{barcode}
```

Si existe:

```text
200
  ↓
product_id
  ↓
POST /replenishments/{id}/lines
```

Mobile debe utilizar el `product_id` retornado por el backend.

---

## 10.2 Producto desconocido

Si el barcode devuelve:

```text
404
```

Mobile debe:

1. permitir reintentar el escaneo;
2. si continúa desconocido, solicitar descripción manual;
3. registrar una línea `PENDING_PRODUCT_RESOLUTION`.

Ejemplo:

```json
{
  "slot_id": "...",
  "quantity": 5,
  "barcode": "123456789",
  "manual_description": "Bebida energética X",
  "product_id": null
}
```

La descripción manual es una **pista/auditoría**, no crea un producto.

---

## 10.3 Barcode ilegible

Si el producto no puede ser escaneado:

```text
No barcode
  ↓
manual_description
  ↓
PENDING_PRODUCT_RESOLUTION
```

Este caso utiliza el mismo mecanismo que un barcode desconocido.

---

# 11. Líneas de reposición

Una línea puede estar:

```text
RESOLVED
```

o:

```text
PENDING_PRODUCT_RESOLUTION
```

### RESOLVED

```text
product_id != null
```

Puede producir un movimiento de inventario.

### PENDING

```text
product_id == null
manual_description != null
```

No produce movimiento de inventario hasta su resolución administrativa.

---

# 12. Cantidad

Mobile captura la cantidad física.

El backend determina si la cantidad es válida.

No corresponde al cliente calcular de forma autoritativa:

* capacidad disponible;
* stock del reponedor;
* saldo de máquina;
* movimientos.

Errores relevantes:

```text
CAPACITY_EXCEEDED
INSUFFICIENT_INVENTORY
```

---

# 13. Sustituciones

Una máquina puede recibir un producto diferente al producto preferido del slot.

La aplicación puede enviar:

```text
replacement_reason
```

cuando corresponda.

La aplicación no decide si la sustitución es válida.

NexoVending valida:

```text
slot configuration
        +
actual product
        +
quantity
        +
business policy
```

---

# 14. Completar una visita

Endpoint:

```http
POST /api/v1/replenishments/{id}/complete
```

Una visita puede completarse con líneas:

```text
RESOLVED
+
PENDING_PRODUCT_RESOLUTION
```

Durante el complete:

```text
RESOLVED
    ↓
InventoryMovement

PENDING
    ↓
no InventoryMovement
```

La aplicación debe mostrar claramente que existen productos pendientes de catálogo cuando la respuesta del backend los indique.

---

# 15. Resolución administrativa posterior

La resolución de una línea pendiente ocurre fuera del flujo normal de campo.

```text
PENDING line
    ↓
Admin creates Product if necessary
    ↓
ResolveReplenishmentLineProduct
    ↓
RESOLVED
    ↓
Deferred InventoryMovement
```

Mobile V1 no crea productos.

Mobile tampoco ejecuta la resolución administrativa.

---

# 16. Idempotencia

Mobile debe generar y persistir `Idempotency-Key` para operaciones mutables.

Especialmente:

* crear reposición;
* agregar línea;
* completar;
* cancelar.

Ejemplo:

```text
UUID / ULID
```

La clave debe sobrevivir a:

* timeout;
* retry;
* pérdida de conexión;
* cierre inesperado de la aplicación.

Misma operación + misma clave + mismo payload:

```text
→ mismo resultado
→ ningún efecto duplicado
```

Misma clave + payload diferente:

```text
→ 409 IDEMPOTENCY_KEY_REUSE
```

---

# 17. Manejo de errores

Mobile debe convertir errores de dominio en UX accionable.

| Código                    | Comportamiento                                |
| ------------------------- | --------------------------------------------- |
| `NOT_FOUND`               | Mostrar recurso no encontrado                 |
| `MACHINE_ACCESS_DENIED`   | Informar que el operador no tiene acceso      |
| `OPERATOR_NOT_FOUND`      | Informar que el operador no está provisionado |
| `CAPACITY_EXCEEDED`       | Solicitar menor cantidad / otro slot          |
| `INSUFFICIENT_INVENTORY`  | No permitir cargar más stock                  |
| `SUBSTITUTION_REJECTED`   | Solicitar corrección                          |
| `INVALID_STATE`           | Recargar estado de reposición                 |
| `IDEMPOTENCY_KEY_REUSE`   | Generar nueva operación sólo si corresponde   |
| `IDEMPOTENCY_IN_PROGRESS` | Esperar/reintentar con la misma clave         |
| `TRANSACTION_CONFLICT`    | Recargar y reintentar                         |

Nunca mostrar stack traces.

---

# 18. Seguridad

Mobile nunca debe:

* almacenar secretos de servidor;
* almacenar credenciales Google de forma insegura;
* fabricar JWT;
* fabricar `principal/...` en producción;
* confiar en `operator_id` recibido del usuario;
* confiar en `tenant_id` enviado en un JSON de negocio;
* asumir permisos desde claims JWT;
* crear productos automáticamente.

El `access_token` debe almacenarse mediante almacenamiento seguro del sistema operativo.

---

# 19. Offline

V1 debe ser **offline-aware**, pero no requiere sincronización offline completa.

La arquitectura debe permitir posteriormente:

```text
Flutter
  ↓
Local persistence
  ↓
Sync engine
  ↓
NexoVending API
```

En V1:

* no existe ledger local como fuente de verdad;
* no existe sincronización completa;
* las operaciones mutables utilizan idempotencia;
* los datos críticos no deben perderse por un retry simple.

---

# 20. Pantallas V1

### Splash

* inicialización;
* recuperación de sesión;
* comprobación básica de configuración.

### Authentication

* Google Sign-In;
* obtención de `id_token`;
* creación de Session JWT.

### Operator Bootstrap

* carga de `/operators/me`;
* validación del contexto operativo.

### Home

* iniciar reposición;
* estado de sesión.

### Machine

* escanear QR;
* ingresar identificador;
* mostrar máquina encontrada.

### Slots

* visualizar posiciones;
* capacidad;
* producto preferido;
* cantidad actual.

### Replenishment

* seleccionar slot;
* escanear producto;
* mostrar producto;
* ingresar cantidad;
* registrar sustitución;
* registrar producto pendiente.

### Review

* revisar líneas;
* distinguir productos resueltos y pendientes;
* confirmar.

### Result

* reposición completada;
* reposición cancelada;
* advertencia de líneas pendientes.

---

# 21. Fuera de alcance V1

| Capacidad                              | Estado                    |
| -------------------------------------- | ------------------------- |
| Administración de productos            | Fuera de Mobile           |
| CRUD de máquinas                       | Fuera                     |
| CRUD de slots                          | Fuera                     |
| Administración de operadores           | Fuera                     |
| Administración de asignaciones         | Fuera                     |
| Administración de inventario           | Fuera del flujo de campo  |
| Resolución administrativa de productos | Fuera del Mobile de campo |
| Ventas                                 | Fuera                     |
| Recetas de café                        | Fuera                     |
| Geofencing                             | Fuera                     |
| Push notifications                     | Fuera                     |
| WhatsApp                               | Fuera                     |
| Chatbot / IA                           | Fuera                     |
| Offline sync completo                  | Futuro                    |
| Dashboard administrativo               | Futuro                    |

---

# 22. Criterios de aceptación

## Authentication

* [ ] Google Sign-In obtiene `id_token`.
* [ ] Mobile puede crear sesión mediante `/auth/session`.
* [ ] Session JWT se almacena de forma segura.
* [ ] Business calls utilizan Bearer JWT.
* [ ] Mobile no fabrica JWT.
* [ ] `/operators/me` devuelve el Operator operativo.
* [ ] Operador no provisionado recibe error apropiado.

## Machine

* [ ] QR resuelve máquina.
* [ ] ID interno resuelve máquina.
* [ ] Acceso a máquina se valida en backend.
* [ ] Mobile no implementa asignaciones como autoridad.

## Slots

* [ ] Mobile obtiene slots desde backend.
* [ ] Se muestra capacidad.
* [ ] Se distingue preferred product de actual product.
* [ ] No se asume una asignación rígida de SKU.

## Replenishment

* [ ] GPS se captura al iniciar visita.
* [ ] Se crea visita `IN_PROGRESS`.
* [ ] Se pueden registrar líneas conocidas.
* [ ] Se pueden registrar líneas pendientes.
* [ ] Una visita puede completarse con pendientes.
* [ ] No se crean productos desde Mobile.

## Idempotency

* [ ] Create usa idempotency key.
* [ ] Add line usa idempotency key.
* [ ] Complete usa idempotency key.
* [ ] Retry no duplica efectos.

## UX

* [ ] Errores 409 tienen tratamiento accionable.
* [ ] Producto pendiente se identifica claramente.
* [ ] Estado de visita siempre es visible.
* [ ] La aplicación no oculta que el inventario por SKU está pendiente.

---

# 23. Definition of Done

V1 queda lista para desarrollo cuando la aplicación pueda ejecutar:

```text
Google Sign-In
    ↓
id_token
    ↓
POST /auth/session
    ↓
Session JWT
    ↓
GET /operators/me
    ↓
Resolve machine
    ↓
Get slots
    ↓
Create replenishment + GPS
    ↓
Scan product
    ├── known
    │     ↓
    │   resolved line
    │
    └── unknown/unreadable
          ↓
       manual description
          ↓
       pending line
    ↓
Review
    ↓
Complete
    ↓
Resolved → inventory movement
Pending  → deferred
```

Y nunca:

```text
Flutter
   ↓
inventar tenant/operator
   ↓
inventar product_id
   ↓
crear Product
   ↓
escribir inventario directamente
```

---

# 24. Estado del backend

El backend necesario para V1 está implementado:

* HTTP API V1;
* execution context;
* unresolved product resolution;
* session authentication;
* monolito fachada;
* Session JWT mediante Nexo Platform 1.11.0.

El cliente Flutter es el siguiente componente a implementar.

---

# 25. Fuentes contractuales

La implementación Mobile debe considerar como fuentes de verdad:

1. `MOBILE_API_CONTRACT.md`
2. `MOBILE_AUTHENTICATION_CONTRACT.md`
3. `API_ARCHITECTURE.md`
4. `REPLENISHMENT_EXECUTION_CONTEXT.md`
5. `ERRORS.md`
6. `IDEMPOTENCY.md`
7. ADRs vigentes de NexoVending y Nexo Platform.

El OpenAPI generado desde el backend debe utilizarse para validar el contrato HTTP.

