# Commit 11 — Unresolved Product Workflow

## Commit

```text
feat(mobile): implement unresolved product workflow
```

## 1. Objetivo

Implementar en **VendingApp** la cascada de identificación de producto cuando el barcode no resuelve catálogo, alineada al contrato V11 de NexoVending (`PENDING_PRODUCT_RESOLUTION`).

Cascada de prioridades (fija para este commit):

```text
1. Lookup por barcode          GET /products/barcode/{barcode}
2. Reintento                   mismo lookup (scan o código manual)
3. Búsqueda por descripción    GET /products?q={text}&limit=&offset=  (publicado)
4. Unresolved product          POST .../lines con PENDING + manual_description
```

Reglas centrales:

* la descripción manual es un **snapshot operacional**, no una creación de producto;
* un producto no catalogado **no inventa** `product_id`;
* la línea PENDING se **persiste** vía el contrato oficial V11 (no borrador local como DoD).

Fuente de verdad backend: [NexoVending/docs/commits/commit11.md](../../../NexoVending/docs/commits/commit11.md), [MOBILE_API_CONTRACT.md](../../../NexoVending/docs/api/MOBILE_API_CONTRACT.md) §6.3b y [PRODUCTS_API.md](../../../NexoVending/docs/api/PRODUCTS_API.md).

---

# 2. Búsqueda de catálogo por texto — gate desbloqueado

## Estado

NexoVending **ya** expone todo lo necesario para Commit 11:

* `GET /products/barcode/{barcode}` (lookup exacto)
* `GET /products?q={text}&limit={n}&offset={n}` (search por texto; §6.3b del contrato móvil)
* `POST /replenishments/{id}/lines` con líneas `pending_product_resolution` (V11)

El gate previo está **satisfecho**. Commit 11 de Flutter es **implementable** contra este contrato.

Prohibido como atajo (sigue vigente):

* inventar búsqueda local / catálogo embebido;
* hardcodear productos en la app;
* saltar de barcode `404` directo a unresolved **sin** paso de search (viola la cascada).

## Contrato publicado (consumir tal cual)

```http
GET /api/v1/products?q={text}&limit={n}&offset={n}
Authorization: Bearer <session-jwt>
```

| Param | Required | Default | Notes |
| --- | --- | --- | --- |
| `q` | yes | — | Trimmed; vacío/whitespace → **422** |
| `limit` | no | `20` | `1..50`; fuera de rango → **422** |
| `offset` | no | `0` | `>= 0`; negativo → **422** |

Match (servidor): substring case-insensitive en `name`, `description`, `brand` (OR). Solo productos **ACTIVE** del tenant. Orden: `name`, luego `product_id`.

Permiso: `product.read` + entitlement `vending.replenishment` (igual que barcode lookup).

**200** — `ProductOut[]`. Lista vacía es éxito, no error.

```json
[
  {
    "product_id": "…",
    "barcode": "7800001",
    "name": "Coca",
    "status": "active",
    "unit": "CAN"
  }
]
```

| Status | Meaning |
| --- | --- |
| 401 | Sesión inválida / ausente |
| 403 | Sin `product.read` o entitlement |
| 422 | `q` / `limit` / `offset` inválidos |

Side effects: **ninguno** (no crea productos, no muta inventario ni líneas).

### Checklist de desbloqueo

- [x] Endpoint de search existe en NexoVending (`GET /api/v1/products`)
- [x] OpenAPI describe request/response/errores
- [x] `MOBILE_API_CONTRACT.md` §6.3b documenta el endpoint móvil
- [x] Lista vacía ≠ error; no auto-crea productos; tenant isolation
- [x] Path y campos fijados: Flutter consume el contrato publicado (sin inventar)

---

# 3. Alcance

## Incluye

* Cascada UI/application: barcode → reintento → search → unresolved PENDING.
* Cliente HTTP de search contra `GET /api/v1/products?q=&limit=&offset=` (§2).
* Modelo de captura `UnresolvedProduct` (UX / input hacia PENDING; no es `Product`).
* Validación y normalización de `manual_description`.
* Extensión del cliente de líneas para POST PENDING (V11).
* Diferenciación: Found (barcode o search) | NotFound | search vacío | Failure técnico | PENDING enviado.
* Integración con reposición activa y pantalla de líneas (Commit 10 / 10c).
* Tests unitarios, HTTP, widget e integración.
* Documentación y ADR del flujo.

## No incluye

* crear productos en el catálogo;
* inventar `product_id`;
* UI admin de resolve / cola `pending-product-resolutions`;
* complete / cancel de reposición (Commits 13–14);
* offline sync;
* inferencia de precio / categoría / slot automático;
* reimplementar search en NexoVending (ya publicado; solo consumir);
* búsqueda local inventada como sustituto del GET search.

---

# 4. Contrato backend V11 (ya implementado)

Backend **sí soporta** líneas no resueltas. No existe “Escenario A — solo borrador en memoria” como camino principal.

### RESOLVED (producto de catálogo conocido)

```json
{
  "slot_id": "…",
  "product_id": "…",
  "quantity": 8,
  "replacement_reason": "OUT_OF_STOCK"
}
```

### PENDING (barcode desconocido / ilegible tras cascada)

```json
{
  "slot_id": "…",
  "quantity": 5,
  "barcode": "123456789",
  "manual_description": "Bebida energética X",
  "product_id": null
}
```

`ReplenishmentLineOut` relevante:

* `product_id`: string | null
* `resolution_status`: `resolved` | `pending_product_resolution`
* `manual_description`: string | null
* `product_description_snapshot`: string
* `barcode_scanned`: string | null

### Invariantes (servidor; el cliente debe respetarlas)

```text
RESOLVED  → product_id IS NOT NULL
PENDING   → product_id IS NULL + manual_description no vacío (strip)
PENDING   → sin replacement_reason
Inválido  → product_id null y sin manual_description
```

Prohibido en móvil:

* inventar `product_id`;
* crear producto;
* enviar línea “normal” RESOLVED sin identidad de catálogo;
* asumir que stock de máquina por SKU ya refleja una línea PENDING.

Admin resolve (`POST .../lines/{line_id}/resolve-product`) y listado pending son **fuera de alcance** de este commit.

---

# 5. Flujo funcional

```text
Scan/Manual barcode
  → GET /products/barcode/{barcode}
      ├── 200 → RESOLVED line (Commit 10 path)
      └── 404 → Retry (scan o código manual)
            → still 404 → Search by description (GET /products?q=…)
                  ├── selección de Product → RESOLVED line
                  └── sin match / operador descarta → Unresolved
                        → capturar manual_description
                        → POST PENDING line
                        → PendingLineSubmitted
```

Desde `NotFound` (barcode), antes de unresolved:

```text
Barcode Not Found
      ├── Scan Again / código manual  → retry lookup
      ├── Search by description       → Found | empty / discard
      └── Cancel
```

Barcode ilegible / sin scan: tras intentos de reintento, el operador puede ir a search; si no hay match, unresolved con `manual_description` (barcode opcional en el POST).

El resultado de search seleccionado es un `Product` de catálogo. `UnresolvedProduct` / `manual_description` **no** es un `Product` válido.

---

# 6. Integración con código existente

Puntos de extensión (no rediseñar capas):

| Área | Archivo | Nota |
| --- | --- | --- |
| Lookup estado / retry | `lib/features/products/application/product_lookup_controller.dart` | Extender estados post-`NotFound` |
| Estados lookup | `lib/features/products/application/product_lookup_state.dart` | Agregar search / manual / pending submitted |
| Lookup API | `lib/features/products/data/` + `ProductLookupService` | Barcode existente; agregar search `GET /products?q=&limit=&offset=` |
| Pantalla loop | `lib/features/replenishment/presentation/replenishment_line_entry_page.dart` | UX cascada en campo (10c) |
| Add line client | `lib/features/replenishment/data/api_replenishment_line_service.dart` | Hoy exige `productId`; extender para PENDING |
| Port add line | `lib/features/replenishment/domain/replenishment_line_service.dart` | Firma opcional `productId` + `manualDescription` / `barcode` |
| Modelo línea | `lib/features/replenishment/domain/replenishment_line.dart` | Ya parsea `resolution_status` / `manual_description` |
| Controller líneas | `lib/features/replenishment/application/replenishment_add_line_controller.dart` | Rama RESOLVED vs PENDING |

---

# 7. Modelo UnresolvedProduct

Crear:

```text
lib/features/products/domain/unresolved_product.dart
```

```dart
class UnresolvedProduct {
  final String? barcode; // opcional si ilegible / no-scan
  final String manualDescription;
}
```

## Invariantes

* `manualDescription` no vacía tras trim;
* no existe `productId` ficticio;
* no se representa como `Product` resuelto;
* `barcode`, si presente, no vacío.

---

# 8. Estados

```text
Idle
Scanning
LookingUp
Found
NotFound
Retrying
SearchingByDescription
SearchResults
SearchEmpty
EnteringManualDescription
PendingLineSubmitted
Failure
```

| Estado | Significado |
| --- | --- |
| `NotFound` | Barcode lookup `404` |
| `Retrying` | Nuevo scan o código manual → vuelve a `LookingUp` |
| `SearchingByDescription` | Request search en curso |
| `SearchResults` | Lista no vacía; operador puede seleccionar `Product` |
| `SearchEmpty` | `200` con lista vacía (no es error técnico) |
| `EnteringManualDescription` | Captura de pista para PENDING |
| `PendingLineSubmitted` | Backend aceptó línea `pending_product_resolution` |
| `Failure` | Error técnico (red, 5xx, etc.); distinto de NotFound / SearchEmpty |

No usar `UnresolvedDraft` / `PendingBackendSupport` como DoD: la línea PENDING se confirma con el POST V11.

---

# 9. Descripción manual

La descripción se ingresa **después** de search fallido o descartado (paso 4).

```text
┌──────────────────────────────┐
│ Producto no resuelto         │
│                              │
│ Código: 7801234567890        │
│                              │
│ Descripción manual           │
│ [ Bebida energética 500 ml ] │
│                              │
│ [ Continuar → línea PENDING ]│
└──────────────────────────────┘
```

### Validación mínima (cliente)

* rechazar vacía / solo espacios;
* trim;
* longitud máxima si el contrato la define.

No validar marca, categoría, precio, SKU ni compatibilidad con máquina.

### Normalización

* trim;
* conservar el texto del operador;
* no transformar nombres comerciales ni inferir atributos.

---

# 10. Reintento de lookup (prioridad 2)

Desde `NotFound`, el operador debe poder:

* escanear nuevamente;
* ingresar código manualmente.

Ambos ejecutan otra vez `ProductLookupService.lookupByBarcode()`.

No crear producto ni línea automáticamente en el reintento.

---

# 11. Búsqueda por descripción (prioridad 3)

Tras reintento(s) fallidos:

1. UI de search con query de texto.
2. `GET /api/v1/products?q={text}&limit=&offset=` (§2).
3. Si el operador selecciona un resultado → flujo RESOLVED (add line con `product_id`).
4. Si lista vacía o el operador descarta → unresolved (prioridad 4).

Cancelar search no debe enviar PENDING ni inventar identidad.
Validar en cliente (UX): no enviar `q` vacío; respetar defaults `limit=20`, `offset=0` y límites `1..50`.

---

# 12. Unresolved → POST PENDING (prioridad 4)

Tras captura válida de `manual_description`:

1. Requiere reposición activa + slot + quantity (mismo contexto que Commit 10 / 10c).
2. `POST /replenishments/{id}/lines` con payload PENDING (§4).
3. Incluir `barcode` cuando exista (pista para admin); omitir o null si no-scan.
4. `Idempotency-Key` como el resto de add-line.
5. UI muestra línea con `resolution_status = pending_product_resolution`.

No enviar `replacement_reason` en PENDING.

---

# 13. No inventar Product ID

Prohibido:

```text
product_id = barcode
product_id = UUID generado en Flutter
```

También prohibido: producto genérico ficticio, producto local sustituto, reutilizar otro `product_id`, tratar la descripción manual como producto resuelto.

El producto solo está resuelto cuando NexoVending entrega identidad de catálogo (barcode 200 o search + selección).

---

# 14. UX

Mensajes claros:

* barcode desconocido ≠ error de red;
* search vacío ≠ fallo técnico;
* línea PENDING ≠ producto registrado en catálogo;
* stock de máquina por SKU puede quedar incompleto hasta resolve admin (informativo; no bloquear add-line).

Acciones desde NotFound / SearchEmpty:

* reintentar barcode;
* buscar por descripción;
* continuar como no resuelto (`manual_description`);
* cancelar.

---

# 15. Manejo de errores

| Situación | Estado / manejo |
| --- | --- |
| Barcode no encontrado | `NotFound` |
| Search lista vacía | `SearchEmpty` |
| Descripción vacía / inválida | validación local |
| 401 | sesión expirada |
| 403 | acceso denegado |
| 409 | conflicto (capacidad, estado, etc.) |
| 422 | validación backend |
| 5xx / timeout / red | `Failure` recuperable + retry |

Distinguir siempre:

```text
Producto no encontrado / sin resultados de búsqueda
```

vs

```text
No fue posible consultar el catálogo
```

---

# 16. Tests unitarios

```text
test/features/products/domain/
```

### UnresolvedProduct

* construcción válida;
* barcode vacío (si se envía);
* descripción vacía / solo espacios;
* normalización trim;
* igualdad;
* ausencia de `productId`.

### Validación de descripción

* válida; trim; vacía; límite de longitud según contrato.

---

# 17. Tests de estado (cascada)

```text
LookingUp → NotFound → Retrying → LookingUp
NotFound → SearchingByDescription → SearchResults → Found
NotFound → SearchingByDescription → SearchEmpty
SearchEmpty → EnteringManualDescription → PendingLineSubmitted
NotFound → Cancel → Idle
```

Stale requests: un resultado antiguo no sobrescribe uno más reciente.

---

# 18. Tests de separación de modelos

* `Product` tiene `product_id` de catálogo;
* `UnresolvedProduct` no tiene `productId`;
* `404` barcode no se convierte en `Product`;
* PENDING no se presenta como producto registrado;
* add-line RESOLVED no se llama sin `product_id`.

---

# 19. Tests de no creación de producto

El flujo manual / PENDING:

* no invoca endpoint de creación de producto;
* no genera `product_id`;
* no modifica catálogo ni inventario localmente.

---

# 20. Tests de reintento y search

* reintento mismo / distinto barcode;
* cancel scan → sin HTTP;
* search con resultados → selección → RESOLVED path;
* search vacío → camino unresolved;
* no inventar path/query distintos del contrato §2.

---

# 21. Tests HTTP

### Search (`GET /api/v1/products`)

* `q` requerido; lista con hits; lista vacía `200`;
* `limit`/`offset` defaults y `422` por fuera de rango / `q` vacío;
* `401` / `403`; sin side effects.

### Add PENDING line

* body con `barcode` + `manual_description` + `product_id: null`;
* body sin barcode + `manual_description`;
* respuesta `resolution_status = pending_product_resolution`;
* `422` / `409` / `401`.

### Negativos

* no enviar RESOLVED sin `product_id`;
* no enviar PENDING sin `manual_description`.

---

# 22. Tests de autenticación

Todo endpoint del flujo:

* `Authorization: Bearer <session-jwt>`;
* no `id_token` Google;
* no `tenant_id` arbitrario desde UI;
* `ApiClient` central.

---

# 23. Tests de reposición

* PENDING asociado al `replenishmentId` activo;
* no contaminar otra reposición / otra máquina;
* cancelar / cambiar contexto invalida captura en curso según reglas de UI;
* idempotency no duplica líneas en reintento de submit.

---

# 24. Widget tests

```text
test/features/products/presentation/
test/features/replenishment/presentation/  # line entry cascade
```

Cubrir:

* NotFound: barcode, mensaje, retry, ir a search;
* Search: campo query, resultados, vacío, seleccionar;
* Manual description: validación; continuar → PENDING;
* Línea PENDING visible como pendiente de catálogo (no como producto resuelto).

---

# 25. Test de seguridad

* no credenciales Google a endpoints de negocio;
* no `product_id` local;
* descripción no es identidad de producto;
* solo campos del contrato;
* no mutar inventario en cliente;
* solo dentro de reposición autorizada.

---

# 26. Test de integración

```text
Authenticated Session
        ↓
Current Replenishment
        ↓
Barcode Lookup → 404
        ↓
Retry → 404
        ↓
Search by description
        ├── hit → RESOLVED line
        └── miss / discard
                ↓
        Manual Description
                ↓
        POST PENDING line
                ↓
        resolution_status = pending_product_resolution
```

---

# 27. Criterios de aceptación

## AC-01 — Código desconocido

Barcode `404` → estado `NotFound`.

## AC-02 — Reintento

Operador puede re-escanear o ingresar código manual; nuevo lookup.

## AC-03 — Search por descripción

Tras reintento fallido, search vía `GET /api/v1/products?q=&limit=&offset=` (§2). No search local ni catálogo embebido.

## AC-04 — Selección desde search

Seleccionar un resultado → línea RESOLVED con `product_id` del catálogo.

## AC-05 — Descripción manual

Tras search vacío o descarte, operador ingresa `manual_description` no vacía.

## AC-06 — Validación

Rechazo de vacía / inválida según contrato.

## AC-07 — Separación de modelos

No convertir NotFound / SearchEmpty en `Product`.

## AC-08 — No inventar identidad

No generar ni inventar `product_id`.

## AC-09 — No crear productos

Descripción manual no crea producto en catálogo.

## AC-10 — POST PENDING

Envía payload V11 (`product_id` null + `manual_description`); no envía línea RESOLVED incompleta.

## AC-11 — Estado explícito

UI distingue: registrado | no encontrado | search vacío | PENDING | error técnico.

## AC-12 — Reposición

PENDING queda en la reposición activa correcta.

## AC-13 — Slot

No asignar slot automático; usa selección del flujo de líneas existente.

## AC-14 — Inventario

Cliente no modifica inventario; PENDING no implica movimiento local.

## AC-15 — Seguridad

Session JWT; sin tenant arbitrario.

## AC-16 — No duplicación

Reintento de lookup / submit no duplica líneas (idempotency).

## AC-17 — Contrato oficial

Únicamente payloads y `resolution_status` del contrato V11 vigente.

## AC-18 — Preparación Commit 12

Líneas PENDING visibles para review posterior sin mezclar con `Product` resuelto.

---

# 28. Documentación (al implementar)

Crear / actualizar:

* `docs/UNRESOLVED_PRODUCT_WORKFLOW.md` — cascada, PENDING V11, search publicado;
* `docs/PRODUCT_LOOKUP.md` — 404, retry, `GET /products?q=`, transición a unresolved;
* `docs/REPLENISHMENT.md` — diagrama con search + PENDING;
* `docs/ARCHITECTURE.md` — separación `Product` / `UnresolvedProduct` / `ReplenishmentLine`;
* ADR (siguiente número disponible; no reutilizar ADR-008 de catalog authority) — decisión: cascada + PENDING sin auto-create;
* README — Unresolved Product ✓; search catalog text como capacidad Vending ya consumida.

Diagrama mínimo en REPLENISHMENT:

```text
Product Lookup
      ↓
Found → RESOLVED line
Not Found
      ├── Retry
      ├── Search by description → Found → RESOLVED line
      └── Unresolved → PENDING line (manual_description)
```

```text
PENDING line ≠ producto de catálogo
PENDING line = observación de campo aceptada por backend
```

---

# 29. Definition of Done

## Gate previo (NexoVending) — satisfecho

0. `GET /api/v1/products?q=&limit=&offset=` publicado, en OpenAPI y en `MOBILE_API_CONTRACT.md` §6.3b. ✓
0b. Flutter consume ese path/query/campos sin inventar variantes.

## Implementación móvil

1. Cascada barcode → retry → search → PENDING implementada.
2. Modelo `UnresolvedProduct` + separación de `Product`.
3. `404` y errores técnicos diferenciados.
4. Reintento scan / código manual.
5. Search vía `GET /api/v1/products` (no local).
6. Selección search → RESOLVED; vacío/descarte → manual.
7. Validación + trim de `manual_description`.
8. No `product_id` ficticio; no creación de producto.
9. `ApiReplenishmentLineService` (y port) soporta POST PENDING.
10. UI muestra `pending_product_resolution` tras éxito.
11. Session JWT; sin tenant arbitrario.
12. Sin mutación de inventario en cliente; sin slot automático indebido.
13. Contexto de reposición correcto; sin contaminación cruzada.
14. Stale requests manejados; idempotency en submit.
15. Tests: unitarios, estado, retry, search, HTTP PENDING, auth, widgets, integración.
16. Docs + ADR + README actualizados.
17. `flutter analyze` y `flutter test` pasan.
18. Sin cambios fuera de alcance.

---

# 30. Resultado esperado

```text
Create Replenishment
        ↓
Barcode Product Lookup
        ├── Product Found → RESOLVED line
        └── Product Not Found
                ├── Retry (scan / código manual)
                ├── Search by description (GET /products?q=)
                │       ├── Product Found → RESOLVED line
                │       └── sin match / discard
                └── Manual Description → POST PENDING line
```

Principio central:

```text
No se convierte una ausencia de catálogo en una identidad inventada.
Search de catálogo ya está publicado en NexoVending; Commit 11 es implementable.
PENDING se persiste con el contrato V11; no con un borrador local como DoD.
```

Siguiente commit:

```text
Commit 12
feat(mobile): implement replenishment review
```
