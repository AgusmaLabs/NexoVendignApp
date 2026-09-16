# Commit 10 — Replenishment Lines

## Commit

```text
feat(mobile): implement replenishment lines
```

## 1. Objetivo

Implementar en **VendingApp** la capacidad de agregar productos identificados a una reposición activa, registrando:

* producto;
* cantidad;
* slot cuando corresponda.

El flujo introducido será:

```text
Authenticated Session
        ↓
Current Operator
        ↓
Current Machine
        ↓
Current Replenishment
        ↓
Product Lookup
        ↓
Product
        ↓
Quantity
        ↓
Optional / Required Slot
        ↓
Replenishment Line
```

Este commit convierte el resultado del Commit 9 en una línea concreta de reposición.

El backend NexoVending continúa siendo la autoridad para:

* validar la reposición;
* validar el producto;
* validar la cantidad;
* validar el slot;
* validar capacidad;
* validar permisos;
* determinar el estado de inventario.

VendingApp únicamente captura y presenta información.

---

# 2. Alcance

## Incluye

* Modelo `ReplenishmentLine`.
* Contrato `ReplenishmentLineService`.
* Implementación HTTP.
* Agregar una línea a una reposición.
* Cantidad de producto.
* Selección de slot cuando corresponda.
* Presentación de slots válidos provenientes del backend.
* Lista de líneas actuales.
* Edición de una línea antes de completar la reposición, si el contrato backend lo permite.
* Eliminación de una línea antes de completar la reposición, si el contrato backend lo permite.
* Estados de creación de línea.
* Manejo de errores.
* Prevención de doble envío.
* Integración con `Current Replenishment`.
* Integración con `Product` del Commit 9.
* Integración con `MachineSlot` del Commit 7.
* Tests unitarios.
* Tests HTTP.
* Tests de estados.
* Tests de widgets.
* Tests de integración.

## No incluye

Este commit **NO** implementa:

* completar reposición;
* cancelar reposición;
* inventario local;
* modificación manual de stock;
* sincronización offline;
* historial;
* creación de productos;
* sustitución automática de productos;
* modificación de capacidad de slots;
* modificación de configuración de máquina.

---

# 3. Principio arquitectónico

La línea de reposición es una entidad de captura operacional.

```text
Product
   +
Quantity
   +
MachineSlot
   ↓
ReplenishmentLine
```

Pero:

```text
ReplenishmentLine
```

no significa todavía:

```text
InventoryMovement
```

ni:

```text
StockDecrement
```

La creación de una línea representa la intención/captura de lo que el operador está cargando.

Las consecuencias definitivas sobre inventario pertenecen al backend y al flujo transaccional correspondiente.

---

# 4. Regla fundamental de Slot

Este commit debe respetar completamente **ADR-014 — Slot as physical container**.

Un slot:

* representa una posición/contenedor físico;
* puede tener capacidad configurable;
* puede tener producto preferido;
* puede tener precio configurado;
* no representa necesariamente un SKU fijo;
* puede estar vacío;
* puede utilizarse con distintos tipos de productos según la configuración física.

Por lo tanto, VendingApp **NO debe implementar reglas como**:

```text
snack → slot
coffee → no slot
```

ni:

```text
preferred_product == product
```

como condición obligatoria.

La aplicación debe utilizar la configuración entregada por NexoVending.

---

# 5. Modelo ReplenishmentLine

Crear:

```text
lib/features/replenishment/domain/replenishment_line.dart
```

Modelo conceptual:

```dart
class ReplenishmentLine {
  final String id;
  final String replenishmentId;
  final Product product;
  final int quantity;
  final String? slotId;
}
```

Los campos exactos deben corresponder al contrato público vigente de NexoVending.

## Invariantes

Una línea debe cumplir:

* `id` válido cuando haya sido creada por backend;
* `replenishmentId` válido;
* `product` válido;
* `quantity > 0`;
* `slotId` opcional únicamente si el contrato lo permite.

No asumir que:

```text
slotId == product.id
```

ni ninguna relación equivalente.

---

# 6. Cantidad

La cantidad debe ser un entero positivo.

Reglas móviles mínimas:

```text
quantity >= 1
```

El frontend puede rechazar:

* cero;
* negativos;
* texto no numérico.

Pero no debe asumir límites máximos.

Por ejemplo, no implementar:

```text
quantity <= 10
```

si ese límite no forma parte del contrato público.

La capacidad real pertenece al backend.

---

# 7. Selección de Slot

La UI debe obtener los slots desde:

```text
Current Machine
      ↓
Machine Detail / Slots
```

El usuario podrá seleccionar un slot cuando la operación lo requiera.

La aplicación debe presentar solamente la configuración que el backend haya entregado.

Ejemplo:

```text
┌──────────────────────────────┐
│ Producto                     │
│ Coca Cola 350 ml             │
│                              │
│ Cantidad                     │
│ [ 12 ]                       │
│                              │
│ Slot                         │
│ ○ A01                        │
│ ○ A02                        │
│ ○ A03                        │
│                              │
│        [ Agregar ]           │
└──────────────────────────────┘
```

No se debe inventar:

* slots;
* capacidades;
* restricciones;
* productos asignados.

---

# 8. Slot opcional versus requerido

La aplicación no debe codificar una regla universal.

El contrato/backend debe determinar si el slot:

```text
required
```

o:

```text
optional
```

para la operación.

Si el contrato devuelve explícitamente que el slot es requerido:

```text
product + quantity + slot
```

serán necesarios.

Si el contrato permite una línea sin slot:

```text
product + quantity
```

será suficiente.

Esta distinción es importante para soportar correctamente:

* máquinas de snacks;
* máquinas de café;
* máquinas mixtas;
* distintas configuraciones físicas.

---

# 9. ReplenishmentLineService

Crear:

```text
lib/features/replenishment/domain/replenishment_line_service.dart
```

Contrato conceptual:

```dart
abstract interface class ReplenishmentLineService {
  Future<ReplenishmentLine> addLine({
    required String replenishmentId,
    required String productId,
    required int quantity,
    String? slotId,
  });
}
```

Si el contrato backend utiliza otro payload, el dominio móvil debe conservar una abstracción equivalente sin exponer detalles HTTP.

---

# 10. ApiReplenishmentLineService

Crear:

```text
lib/features/replenishment/infrastructure/api_replenishment_line_service.dart
```

Responsabilidades:

1. recibir datos de la línea;
2. construir el request;
3. utilizar `ApiClient`;
4. utilizar automáticamente el Session JWT;
5. incluir `X-Request-Id` mediante la infraestructura existente;
6. mapear respuesta a `ReplenishmentLine`;
7. mapear errores HTTP.

No debe:

* acceder directamente a SecureStorage;
* implementar reglas de negocio del backend;
* modificar inventario local.

---

# 11. Contrato HTTP

Utilizar exclusivamente el endpoint definido por el contrato público vigente de NexoVending.

Conceptualmente:

```http
POST /api/v1/replenishments/{replenishment_id}/lines
Authorization: Bearer <session-jwt>
Content-Type: application/json
X-Request-Id: <request-id>
```

Payload conceptual:

```json
{
  "product_id": "product-123",
  "quantity": 12,
  "slot_id": "slot-A01"
}
```

Si `slot_id` no es requerido por el contrato:

```json
{
  "product_id": "product-123",
  "quantity": 12
}
```

No enviar:

```text
tenant_id
operator_id
```

salvo que estén explícitamente definidos como parte del contrato público.

---

# 12. Estado de Add Line

Crear estados explícitos:

```text
Idle
Adding
Added
Failure
```

Opcionalmente:

```text
ValidationFailure
```

si la arquitectura actual separa validaciones locales de errores de backend.

## Idle

Formulario disponible.

## Adding

Request en curso.

Durante este estado:

* deshabilitar botón;
* evitar doble submit;
* mostrar progreso.

## Added

La línea fue aceptada por backend.

## Failure

La operación falló.

Debe poder reintentarse cuando sea seguro hacerlo.

---

# 13. Lista de líneas

El estado de la reposición debe permitir representar:

```text
Current Replenishment
    ├── Line 1
    ├── Line 2
    ├── Line 3
    └── ...
```

Crear un contexto o estado de líneas asociado a:

```text
CurrentReplenishmentContext
```

La lista debe provenir del backend.

No mantener un ledger paralelo como autoridad local.

---

# 14. Agregar línea

El flujo esperado:

```text
Product Lookup
      ↓
Product Found
      ↓
Enter Quantity
      ↓
Select Slot if required
      ↓
Add Line
      ↓
Backend
      ↓
ReplenishmentLine
      ↓
Current Replenishment updated
```

La UI debe permitir volver al lookup después de agregar una línea.

---

# 15. Repetir producto

VendingApp no debe decidir por sí sola si un producto puede repetirse.

Ejemplo:

```text
Product A
quantity 5
slot A01
```

y posteriormente:

```text
Product A
quantity 3
slot A02
```

puede ser válido dependiendo del modelo backend.

Si NexoVending rechaza la operación, el móvil debe presentar el error.

No implementar una restricción local de unicidad salvo que forme parte explícita del contrato.

---

# 16. Edición de línea

Si el contrato público soporta modificación de líneas, se puede implementar:

```text
Edit quantity
Edit slot
```

utilizando el endpoint oficial.

La aplicación no debe modificar una línea localmente como si eso fuera suficiente.

La fuente de verdad continúa siendo NexoVending.

Si el contrato actual no soporta edición, esta funcionalidad queda fuera del commit y debe dejarse documentada como pendiente.

---

# 17. Eliminación de línea

Misma regla.

Si el contrato soporta:

```text
DELETE /.../lines/{line_id}
```

se puede implementar.

Si no existe en el contrato actual:

* no inventar endpoint;
* no simular eliminación local;
* dejar la capacidad para un commit posterior.

---

# 18. Errores

Mapear como mínimo:

| HTTP    | Significado móvil                      |
| ------- | -------------------------------------- |
| 200/201 | línea creada                           |
| 400     | request inválido                       |
| 401     | sesión expirada                        |
| 403     | acceso denegado                        |
| 404     | reposición/producto/slot no encontrado |
| 409     | conflicto de estado                    |
| 422     | regla de negocio / validación          |
| 429     | rate limit                             |
| 5xx     | error temporal                         |

---

# 19. Errores de negocio

Especial atención a:

### Reposición no editable

El backend puede rechazar la línea porque la reposición:

```text
completed
cancelled
```

o está en otro estado no editable.

El móvil debe mostrar un estado coherente.

---

### Producto inválido

Aunque el producto haya sido encontrado previamente, el backend sigue siendo la autoridad.

Puede haber cambiado entre:

```text
lookup
```

y:

```text
add line
```

Por lo tanto:

```text
Product encontrado ≠ Product garantizado al momento del write
```

---

### Slot inválido

El backend puede rechazar:

* slot inexistente;
* slot perteneciente a otra máquina;
* slot no disponible;
* slot incompatible con la operación.

El móvil no debe intentar corregir esto inventando otra asignación.

---

# 20. Idempotencia

La operación de agregar una línea es una mutación.

Debe respetar el mecanismo de idempotencia definido por el contrato backend.

Si NexoVending requiere una clave idempotente:

```http
Idempotency-Key: <key>
```

la aplicación debe generarla y conservarla durante el retry de **la misma operación lógica**.

No generar una nueva clave para cada retry de la misma operación.

Ejemplo:

```text
Tap Add
   ↓
request-id / idempotency-key A
   ↓
timeout
   ↓
retry
   ↓
same idempotency-key A
```

No:

```text
retry
   ↓
idempotency-key B
```

Esto evita duplicar líneas.

---

# 21. No usar Product como autoridad de inventario

El `Product` obtenido en Commit 9 contiene información de catálogo.

No debe utilizarse para inferir:

```text
stock disponible
```

ni:

```text
cantidad máxima de carga
```

ni:

```text
capacidad del slot
```

Esos datos pertenecen al contexto/backend correspondiente.

---

# 22. Tests unitarios

Crear:

```text
test/features/replenishment/domain/
```

## ReplenishmentLine

Probar:

* construcción válida;
* quantity > 0;
* replenishment ID válido;
* product válido;
* slot opcional;
* igualdad.

---

# 23. Tests de quantity

Probar:

```text
1       → válido
5       → válido
999999  → permitido por modelo si backend aún debe validar límite
0       → inválido
-1      → inválido
```

La aplicación no debe imponer límites comerciales no definidos.

---

# 24. Tests de slot

Probar:

### Slot requerido

Sin slot:

```text
validation failure
```

### Slot proporcionado

Debe generar payload correcto.

### Slot opcional

La línea puede enviarse sin `slot_id`.

### Slot perteneciente a otra máquina

La aplicación debe aceptar la respuesta de backend como error y no inventar una corrección.

---

# 25. Tests de ApiReplenishmentLineService

Crear:

```text
test/features/replenishment/infrastructure/
```

Probar:

### 201/200

Response:

```text
HTTP → ReplenishmentLine
```

### 400

Mapeo correcto.

### 401

Sesión expirada.

### 403

Acceso denegado.

### 404

Recurso no encontrado.

### 409

Conflicto.

### 422

Regla de negocio.

### 429

Rate limit.

### 500

Error recuperable.

### Timeout

Error de red.

---

# 26. Test del payload

Verificar exactamente:

```json
{
  "product_id": "...",
  "quantity": 5,
  "slot_id": "..."
}
```

cuando el slot esté presente.

Y:

```json
{
  "product_id": "...",
  "quantity": 5
}
```

cuando sea opcional y no haya sido seleccionado.

No deben enviarse campos no definidos por el contrato.

---

# 27. Test de autenticación

Verificar:

```http
Authorization: Bearer <session-jwt>
```

y que:

* no se use Google `id_token`;
* no se almacene el JWT nuevamente;
* no se envíe tenant arbitrario;
* el `ApiClient` central gestione autenticación.

---

# 28. Test de idempotencia

Caso obligatorio:

```text
Add Line
   ↓
timeout
   ↓
retry
```

Debe utilizar la misma clave idempotente para la misma operación lógica.

Además:

```text
same operation
    → same key

new line operation
    → new key
```

---

# 29. Test de doble tap

Simular:

```text
tap Add
tap Add
```

antes de recibir la respuesta.

Debe resultar en:

```text
1 logical operation
```

y no en dos requests independientes.

---

# 30. Tests de estado

Probar:

```text
Idle
 ↓
Adding
 ↓
Added
```

y:

```text
Idle
 ↓
Adding
 ↓
Failure
 ↓
retry
 ↓
Adding
```

Durante `Adding`:

* botón deshabilitado;
* no permitir doble submit.

---

# 31. Tests de integración con Current Replenishment

Verificar:

```text
Current Replenishment
      ↓
Add Line
      ↓
Current Replenishment
      ↓
lines += new line
```

El nuevo estado debe asociarse a la reposición correcta.

---

# 32. Test de aislamiento entre reposiciones

Crear:

```text
Replenishment A
Replenishment B
```

Agregar una línea a A.

Verificar que B no reciba la línea.

---

# 33. Test de aislamiento entre máquinas

Crear:

```text
Machine A
    └── Replenishment A

Machine B
    └── Replenishment B
```

La línea agregada a A no puede terminar asociada a B.

El `machine_id` no debe ser inventado en el payload si no forma parte del contrato; la asociación debe derivarse del `replenishment_id` según el backend.

---

# 34. Test de no mutación de inventario local

Después de agregar una línea:

```text
inventory state
```

debe permanecer sin modificaciones locales.

La línea es captura de reposición.

El inventario definitivo se resuelve en backend.

---

# 35. Widget tests

Crear:

```text
test/features/replenishment/presentation/
```

Probar:

## Formulario

Debe mostrar:

* producto;
* cantidad;
* slot cuando corresponda;
* botón agregar.

## Validación

Cantidad:

```text
0
```

no permite submit.

## Loading

Mientras se agrega:

```text
Adding
```

el botón queda deshabilitado.

## Success

Mostrar la nueva línea.

## Error

Mostrar error y permitir retry.

---

# 36. Test de flujo completo

Crear un integration test:

```text
Authenticated Session
        ↓
Operator
        ↓
Machine
        ↓
Replenishment
        ↓
Product Lookup
        ↓
Product
        ↓
Quantity
        ↓
Slot
        ↓
Add Line
        ↓
ReplenishmentLine
```

Debe terminar con una línea correctamente asociada a la reposición.

No debe completar la reposición.

---

# 37. Criterios de aceptación

## AC-01 — Producto convertido en línea

Dado un `Product` obtenido mediante Commit 9,

cuando el operador ingresa una cantidad válida,

entonces puede iniciar la creación de una línea.

---

## AC-02 — Cantidad válida

Una cantidad `> 0` puede enviarse al backend.

---

## AC-03 — Cantidad inválida

Una cantidad `<= 0` no genera request.

---

## AC-04 — Slot

Cuando el contrato indique que el slot es requerido, la aplicación no permite crear la línea sin seleccionarlo.

---

## AC-05 — Slot opcional

Cuando el contrato permita omitir slot, la aplicación puede crear la línea sin `slot_id`.

---

## AC-06 — No hardcodear tipo de máquina

La aplicación no puede decidir:

```text
snack → slot
coffee → no slot
```

por tipo de máquina.

La configuración backend es la autoridad.

---

## AC-07 — Producto preferido

`preferred_product` del slot no significa que el producto seleccionado sea obligatorio.

La aplicación debe permitir la operación siempre que el backend la acepte.

---

## AC-08 — Creación

Cuando el backend acepta la operación, la nueva `ReplenishmentLine` aparece asociada a la reposición actual.

---

## AC-09 — Autenticación

La operación utiliza:

```http
Authorization: Bearer <session-jwt>
```

---

## AC-10 — Tenant

La aplicación no puede seleccionar ni sustituir arbitrariamente el tenant.

---

## AC-11 — Idempotencia

Un retry de la misma operación lógica no puede crear accidentalmente múltiples líneas.

---

## AC-12 — Doble tap

Dos taps rápidos no producen dos operaciones independientes.

---

## AC-13 — Backend authority

Errores de negocio provenientes del backend se presentan al usuario y no son reemplazados por reglas inventadas en Flutter.

---

## AC-14 — No inventar límites

VendingApp no impone una capacidad máxima de cantidad que no esté definida por el contrato.

---

## AC-15 — No modificar inventario

Agregar una línea no modifica directamente el inventario local.

---

## AC-16 — Reposición correcta

La línea siempre pertenece a la reposición actualmente activa.

---

## AC-17 — Máquina correcta

Una línea no puede terminar asociada accidentalmente a una reposición de otra máquina.

---

## AC-18 — No completar

Agregar una línea no cambia el estado de la reposición a `completed`.

---

## AC-19 — Preparado para Review

El operador puede volver al flujo de producto después de agregar una línea y continuar agregando productos.

---

# 38. Documentación

Crear:

```text
docs/REPLENISHMENT_LINES.md
```

Debe documentar:

* propósito;
* modelo;
* flujo;
* cantidad;
* slot;
* estados;
* errores;
* idempotencia;
* seguridad;
* relación con Product;
* relación con MachineSlot;
* límites del commit.

---

# 39. Actualizar REPLENISHMENT.md

La sección de flujo debe pasar de:

```text
Create Replenishment
      ↓
Product Lookup
```

a:

```text
Create Replenishment
      ↓
Product Lookup
      ↓
Quantity
      ↓
Slot when required
      ↓
Replenishment Line
```

---

# 40. Actualizar MACHINE_DETAIL.md

Documentar que los slots obtenidos en Commit 7 ahora pueden ser utilizados por el flujo de reposición.

Mantener explícitamente:

```text
MachineSlot = physical container
```

y no:

```text
MachineSlot = fixed SKU
```

---

# 41. Actualizar ARCHITECTURE.md

Agregar:

```text
Product
   ↓
Replenishment Line
```

y documentar:

```text
Catalog authority
    NexoVending

Replenishment authority
    NexoVending

Inventory authority
    NexoVending
```

VendingApp actúa como:

```text
capture + presentation + API consumer
```

---

# 42. ADR

Crear:

```text
docs/adr/ADR-007-replenishment-line-authority.md
```

Si `ADR-007` ya existe, utilizar el siguiente número disponible.

## Decisión

La creación de una línea de reposición se ejecuta mediante NexoVending.

VendingApp:

* captura producto;
* captura cantidad;
* captura slot;
* solicita la operación;
* muestra resultado.

NexoVending:

* valida;
* autoriza;
* persiste;
* aplica reglas de negocio;
* mantiene consistencia.

---

# 43. Actualizar README

Estado esperado:

```text
Authentication             ✓
Session                    ✓
Operator Bootstrap         ✓
Machine Identification     ✓
Machine Detail / Slots     ✓
Replenishment Creation     ✓
Barcode Product Lookup     ✓
Replenishment Lines        ✓
Unresolved Product         pending
Replenishment Review       pending
Replenishment Completion   pending
Replenishment Cancellation pending
```

---

# 44. Definition of Done

El Commit 10 solamente se considera terminado cuando:

1. Existe `ReplenishmentLine`.
2. Existe `ReplenishmentLineService`.
3. Existe implementación HTTP.
4. El servicio utiliza `ApiClient`.
5. La autenticación utiliza Session JWT.
6. Existe captura de cantidad.
7. `quantity > 0` es obligatorio.
8. No se inventan límites de cantidad.
9. Existe integración con `Product` del Commit 9.
10. Existe integración con `MachineSlot` del Commit 7.
11. Se respeta ADR-014.
12. No se hardcodean reglas snack/coffee.
13. `preferred_product` no se trata como SKU obligatorio.
14. Se soporta slot requerido según contrato.
15. Se soporta slot opcional según contrato.
16. Se crea una línea mediante el endpoint público correcto.
17. La línea queda asociada a la reposición correcta.
18. Se evita doble submit.
19. Se respeta idempotencia.
20. Los retries utilizan la misma idempotency key para la misma operación.
21. Se manejan 401/403/404/409/422/429/5xx.
22. Se manejan errores de red y timeout.
23. Existe lista de líneas de la reposición.
24. El estado `Adding` bloquea acciones duplicadas.
25. El estado `Added` actualiza correctamente el contexto.
26. No se modifica inventario local.
27. No se crea catálogo local.
28. No se crea ningún producto.
29. No se completa la reposición.
30. No se cancela la reposición.
31. Existen tests unitarios.
32. Existen tests de validación.
33. Existen tests de slot.
34. Existen tests HTTP.
35. Existen tests de autenticación.
36. Existen tests de idempotencia.
37. Existen tests de doble tap.
38. Existen widget tests.
39. Existe test de integración del flujo completo.
40. Existe test de aislamiento entre reposiciones.
41. Existe test de aislamiento entre máquinas.
42. Existe test de no mutación de inventario.
43. `flutter analyze` pasa sin errores.
44. `flutter test` pasa completamente.
45. `docs/REPLENISHMENT_LINES.md` está actualizado.
46. `REPLENISHMENT.md` está actualizado.
47. `MACHINE_DETAIL.md` está actualizado.
48. `ARCHITECTURE.md` está actualizado.
49. ADR correspondiente está documentado.
50. README refleja el nuevo estado.
51. No existen dependencias HTTP en el dominio.
52. No existen dependencias del dominio hacia el SDK de cámara.
53. No se introducen cambios fuera del alcance del commit.

---

# 45. Resultado esperado

Al finalizar Commit 10, el flujo funcional queda:

```text
Google Authentication
        ↓
Vending Session
        ↓
Operator Bootstrap
        ↓
Machine Identification
        ↓
Machine Detail + Slots
        ↓
Create Replenishment
        ↓
Barcode Product Lookup
        ↓
Product
        ↓
Quantity
        ↓
Slot when required
        ↓
Replenishment Line
```

La reposición puede contener múltiples líneas:

```text
Replenishment
 ├── Coca Cola 350 ml × 12 → Slot A01
 ├── Papas Fritas × 8      → Slot A02
 ├── Café × 20             → Container C01
 └── ...
```

pero todavía **no se considera finalizada**.

El siguiente límite natural del flujo será:

```text
Commit 11
feat(mobile): implement unresolved product workflow
```

para tratar explícitamente el caso en que el barcode no tenga producto conocido, antes de construir el flujo de revisión y finalización.
