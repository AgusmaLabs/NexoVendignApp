# Commit 8 — Implementar creación de reposición

**Commit:**

```text
feat(mobile): implement replenishment creation
```

---

# 1. Objetivo

Implementar en VendingApp el flujo de **creación de una sesión de reposición** para la máquina actualmente seleccionada.

El flujo debe ser:

```text
Authenticated Session
        ↓
Vending Operator
        ↓
Current Machine
        ↓
Create Replenishment
        ↓
NexoVending
        ↓
Replenishment
        ↓
Current Replenishment Context
```

Este commit establece la transacción de negocio sobre la cual se construirán los siguientes pasos:

```text
Replenishment
    ↓
Add product line
    ↓
Review
    ↓
Complete / Cancel
```

---

# 2. Responsabilidad del commit

Commit 8 responde:

> "El operador está frente a una máquina determinada y quiere comenzar una reposición."

No responde todavía:

> "¿Qué producto está reponiendo?"

Eso corresponde al siguiente commit.

Por lo tanto:

```text
Commit 8
Create Replenishment
```

y:

```text
Commit 9
Barcode Product Lookup
```

deben permanecer separados.

---

# 3. Alcance

## Incluye

* Modelo `Replenishment`.
* Estado de reposición.
* `ReplenishmentService`.
* Endpoint de creación.
* Asociación con máquina actual.
* Asociación implícita con operador autenticado.
* Creación de reposición vacía.
* Contexto de reposición actual.
* Protección contra doble creación accidental.
* Manejo de errores.
* UI de inicio de reposición.
* Tests unitarios.
* Tests de integración HTTP.
* Tests widget.
* Tests de seguridad.
* Documentación.

## No incluye

No implementar todavía:

```text
Product lookup
Barcode scanning
Add replenishment line
Quantity entry
Slot assignment
Manual product description
Inventory movement
Stock deduction
GPS capture
Completion
Cancellation
Offline synchronization
```

---

# 4. Contrato HTTP

Utilizar el endpoint público definido en el contrato vigente de NexoVending:

```http
POST /api/v1/replenishments
Authorization: Bearer <session-jwt>
Content-Type: application/json
X-Request-Id: <request-id>
```

El payload exacto debe corresponder al contrato HTTP actual.

No inventar campos.

Si el contrato requiere explícitamente `machine_id`, utilizarlo.

Si el backend obtiene la máquina desde otro contexto contractual, respetar ese contrato.

La fuente de verdad es:

```text
Mobile API Contract — NexoVending
```

---

# 5. Flujo

El flujo esperado es:

```text
Machine identified
        ↓
User taps "Start replenishment"
        ↓
POST /replenishments
        ↓
201 Created
        ↓
Replenishment created
        ↓
Current Replenishment
```

El resultado debe contener como mínimo la información que el cliente necesita para continuar:

```text
replenishment_id
status
machine_id
```

y cualquier otro campo definido por el contrato.

---

# 6. Modelo `Replenishment`

Crear:

```text
features/replenishment/domain/entities/replenishment.dart
```

Conceptualmente:

```dart
class Replenishment {
  final String id;
  final String machineId;
  final ReplenishmentStatus status;
}
```

El modelo real debe seguir el contrato de NexoVending.

No introducir estados móviles que no existan en el backend salvo que sean estados puramente de UI.

---

# 7. Estado de backend

Si NexoVending define un estado inicial, por ejemplo:

```text
PENDING
```

o:

```text
IN_PROGRESS
```

la aplicación debe conservar exactamente esa semántica.

No renombrar silenciosamente:

```text
PENDING → ACTIVE
```

si el valor forma parte del contrato HTTP.

La aplicación puede tener un estado de presentación separado:

```text
Creating
Created
Failure
```

pero no debe modificar el estado de negocio.

---

# 8. ReplenishmentService

Crear:

```dart
abstract interface class ReplenishmentService {
  Future<Replenishment> createReplenishment({
    required String machineId,
  });
}
```

Implementación:

```text
ApiReplenishmentService
```

Responsabilidades:

1. recibir la máquina actual;
2. construir el request;
3. llamar al endpoint;
4. mapear la respuesta;
5. devolver `Replenishment`.

No debe:

* consultar SecureStorage directamente;
* crear tokens;
* determinar tenant;
* validar permisos de negocio;
* modificar inventario localmente;
* agregar líneas.

---

# 9. Machine Context → Replenishment

La reposición debe estar vinculada a la máquina actualmente seleccionada.

Flujo:

```text
Current Machine
      ↓
machine.id
      ↓
Create Replenishment
      ↓
Replenishment.machine_id
```

Nunca permitir:

```text
Current Machine = A
Request machine_id = B
```

si la API utiliza `machine_id` en el request.

El controller/use case debe utilizar la máquina que está realmente en contexto.

---

# 10. Operator Context

La identidad del operador no debe enviarse arbitrariamente desde la UI.

La aplicación ya posee:

```text
Session JWT
Operator Context
```

NexoVending debe determinar el operador autenticado mediante la sesión.

No hacer:

```json
{
  "operator_id": "..."
}
```

salvo que el contrato HTTP explícitamente lo requiera.

Si el backend ya resuelve el operador desde JWT, el cliente no debe duplicar esa responsabilidad.

---

# 11. Tenant

La aplicación tampoco debe enviar un tenant arbitrario.

La relación es:

```text
Session JWT
      ↓
NexoVending
      ↓
Tenant
      ↓
Operator
      ↓
Machine
      ↓
Replenishment
```

No implementar:

```text
machine_id + tenant_id
```

como mecanismo de autorización móvil.

---

# 12. Current Replenishment Context

Crear un contexto de aplicación:

```text
Current Replenishment
```

Conceptualmente:

```text
Operator Context
       +
Machine Context
       +
Replenishment Context
```

El contexto debe contener:

```text
replenishment.id
replenishment.machineId
replenishment.status
```

y cualquier información necesaria para continuar el flujo.

No almacenar:

```text
JWT
Google id_token
credentials
```

---

# 13. Regla de una reposición activa

Debe evitarse la creación accidental de múltiples reposiciones por múltiples taps.

Durante:

```text
Creating
```

el botón debe quedar deshabilitado.

Flujo:

```text
Tap
 ↓
Creating
 ↓
Button disabled
 ↓
Request
```

No:

```text
Tap
Tap
Tap
 ↓
3 POST requests
```

---

# 14. Idempotencia

El endpoint de creación debe respetar la estrategia de idempotencia definida por NexoVending.

Si el contrato ya define un mecanismo como:

```http
Idempotency-Key: <key>
```

la aplicación debe utilizarlo.

La clave debe representar una única intención de creación.

Por ejemplo:

```text
User starts replenishment
        ↓
generated operation id
        ↓
same Idempotency-Key on retry
```

Una repetición de la misma operación no debe crear dos reposiciones.

Importante:

**No implementar aquí una solución paralela de idempotencia si el contrato ya la define.**

El Commit 15 de la planificación original puede reforzar resiliencia/idempotencia transversal, pero Commit 8 debe al menos respetar el contrato existente para creación.

---

# 15. Request ID

El request debe utilizar la infraestructura creada en Commit 2:

```http
X-Request-Id: <generated-request-id>
```

No generar manualmente IDs desde la feature si `ApiClient` ya los gestiona.

---

# 16. UI

Crear:

```text
ReplenishmentStartPage
```

La pantalla debe mostrar la máquina actual:

```text
Machine
────────────────
<Machine name>
<Machine identifier>

Ready to replenish

[Start replenishment]
```

Antes de crear:

```text
Start replenishment
```

Durante:

```text
Creating replenishment...
```

Después:

```text
Replenishment started
```

y permitir continuar al próximo paso.

---

# 17. Protección contra máquina inexistente

No permitir crear una reposición si:

```text
Current Machine == null
```

Esto debe ser una condición de aplicación, no una llamada HTTP innecesaria.

Flujo:

```text
No machine context
        ↓
Cannot create replenishment
```

La aplicación debe dirigir al flujo de identificación de máquina.

No inventar un `machine_id`.

---

# 18. Protección contra operador inexistente

No iniciar una reposición si no existe un operador Vending válido.

Debe existir:

```text
Authenticated Session
+
Current Operator
+
Current Machine
```

antes de crear:

```text
Replenishment
```

Si falta operador:

```text
Operator bootstrap
```

debe ejecutarse nuevamente o la sesión debe volver al flujo correspondiente.

---

# 19. Estados de UI

Definir como mínimo:

```text
Initial
Creating
Created
Failure
```

Opcionalmente:

```text
NoMachine
NoOperator
SessionExpired
```

si la arquitectura de estados existente lo requiere.

No duplicar innecesariamente estados ya administrados por Session/Operator Context.

---

# 20. Manejo de errores

## 401 Unauthorized

La sesión dejó de ser válida.

Flujo:

```text
Create replenishment
        ↓
401
        ↓
Session expired
        ↓
Clear session
        ↓
Authentication
```

---

## 403 Forbidden

El operador no tiene autorización para iniciar una reposición en esa máquina.

Mostrar:

```text
You do not have permission to replenish this machine.
```

No intentar crear una reposición local.

---

## 404 Not Found

La máquina ya no existe o no está disponible.

Mostrar:

```text
Machine is no longer available.
```

El contexto de máquina puede invalidarse según la política definida.

---

## 409 Conflict

Este caso es especialmente importante.

Si NexoVending informa que ya existe una reposición activa para la máquina:

```text
409
 ↓
Existing replenishment
```

la aplicación debe seguir el contrato.

Si la API devuelve la reposición existente, utilizarla.

No crear otra.

Si únicamente informa conflicto, mostrar:

```text
A replenishment is already in progress for this machine.
```

---

## 422 Validation

Mostrar error de request sin convertirlo en error genérico.

---

## 5xx

Mostrar error recuperable:

```text
Unable to start replenishment right now.
```

Permitir retry.

---

## Network / Timeout

Utilizar las excepciones existentes:

```text
NetworkException
TimeoutException
```

---

# 21. Reintento

El retry debe conservar la intención original.

Incorrecto:

```text
Failure
 ↓
generate new operation
 ↓
new POST
```

si eso puede generar una segunda reposición.

Correcto:

```text
Failure
 ↓
Retry same logical operation
 ↓
same idempotency semantics
```

La implementación exacta debe seguir el contrato de idempotencia del backend.

---

# 22. Navegación

Después de crear correctamente la reposición:

```text
Machine Detail
       ↓
Start Replenishment
       ↓
Replenishment created
       ↓
Replenishment flow
```

El siguiente commit deberá introducir el lookup de producto.

Por lo tanto, puede existir temporalmente una pantalla:

```text
Replenishment in progress
Ready to add products
```

No implementar todavía el scanner.

---

# 23. No crear líneas vacías

La creación de la reposición no debe crear una línea ficticia.

Después de Commit 8:

```text
Replenishment
lines = []
```

hasta que Commit 10 agregue la primera línea.

No crear:

```text
Product = null
Quantity = 0
```

como pseudo-linea.

---

# 24. Inventory boundary

Crear una reposición **no debe modificar inventario**.

El flujo correcto será posteriormente:

```text
Create replenishment
       ↓
Add lines
       ↓
Complete replenishment
       ↓
Backend inventory transaction
```

No ejecutar:

```text
POST create replenishment
       ↓
decrement stock
```

en este commit.

---

# 25. Tests unitarios

## 25.1 Create success

Given:

```text
valid operator
valid machine
valid session
```

When:

```text
createReplenishment()
```

Then:

```text
Replenishment returned
```

---

## 25.2 Correct machine ID

Verificar que se utiliza exactamente:

```text
CurrentMachine.id
```

---

## 25.3 No machine

Given:

```text
CurrentMachine == null
```

Then:

```text
No HTTP request
```

---

## 25.4 No operator

Given:

```text
CurrentOperator == null
```

Then:

```text
No HTTP request
```

---

## 25.5 401

Verificar transición a sesión expirada.

---

## 25.6 403

Verificar estado de acceso denegado.

---

## 25.7 404

Verificar máquina no disponible.

---

## 25.8 409

Verificar tratamiento de reposición existente.

---

## 25.9 422

Verificar validación.

---

## 25.10 5xx

Verificar estado recuperable.

---

## 25.11 Timeout

Debe producir:

```text
TimeoutException
```

---

## 25.12 Network failure

Debe producir:

```text
NetworkException
```

---

# 26. Tests de doble tap

Este test es obligatorio.

Escenario:

```text
User taps Start
User taps Start again immediately
```

Debe producir:

```text
1 logical creation
```

y:

```text
1 POST
```

si el request está todavía en progreso.

---

# 27. Tests de idempotencia

Si el contrato utiliza `Idempotency-Key`, verificar:

```text
same logical operation
        ↓
same key
```

y:

```text
different logical operation
        ↓
different key
```

No reutilizar globalmente una única clave.

---

# 28. Tests de Current Replenishment Context

Verificar:

```text
Create success
      ↓
CurrentReplenishment = returned
```

y:

```text
Create failure
      ↓
CurrentReplenishment unchanged
```

si ya existe un contexto válido.

Nunca almacenar un objeto parcial.

---

# 29. Tests de máquina cruzada

Caso:

```text
Machine A selected
      ↓
Start replenishment
```

Debe enviar:

```text
machine_id = A
```

No:

```text
machine_id = stale machine
```

Caso:

```text
Machine A
 ↓
change to Machine B
 ↓
start
```

Debe utilizar:

```text
machine_id = B
```

---

# 30. Tests de stale response

Escenario:

```text
Machine A
 ↓
Create replenishment A

Machine changes to B

Response A arrives
```

La respuesta no debe instalar una reposición de A como:

```text
Current Replenishment
```

si el contexto actual ya corresponde a B.

Debe validarse la relación:

```text
replenishment.machineId == currentMachine.id
```

antes de actualizar el contexto, cuando corresponda.

---

# 31. Tests de integración HTTP

Verificar:

```http
POST /api/v1/replenishments
Authorization: Bearer <session-jwt>
X-Request-Id: <request-id>
Content-Type: application/json
```

y:

```json
{
  "machine_id": "<current-machine-id>"
}
```

**si ese es el payload definido por el contrato.**

No fijar en tests campos que el contrato real no contemple.

---

# 32. Test de respuesta

Probar respuesta exitosa con:

```text
replenishment_id
machine_id
status
```

y cualquier campo adicional obligatorio.

Verificar deserialización completa.

---

# 33. Test de inventory isolation

Crear una prueba que confirme que crear una reposición:

```text
does not call inventory endpoints
```

y:

```text
does not mutate local inventory
```

---

# 34. Tests widget

## 34.1 Initial

Debe mostrar:

```text
Machine
Start replenishment
```

---

## 34.2 Creating

Después del tap:

```text
Creating replenishment...
```

El botón debe quedar deshabilitado.

---

## 34.3 Success

Debe mostrar reposición iniciada.

---

## 34.4 Failure

Debe mostrar error y retry.

---

## 34.5 403

Debe mostrar acceso denegado.

---

## 34.6 409

Debe mostrar reposición existente.

---

## 34.7 401

Debe volver al flujo de autenticación.

---

## 34.8 No machine

Debe impedir iniciar la operación.

---

# 35. Tests de seguridad

Verificar:

* JWT nunca aparece en logs.
* Authorization header nunca aparece en logs.
* Google `id_token` nunca aparece en el request.
* `operator_id` no se fabrica desde la UI.
* `tenant_id` no puede ser modificado arbitrariamente.
* no se almacenan credenciales en `Replenishment`.
* no se modifican inventarios localmente.

---

# 36. Documentación

Actualizar:

```text
README.md
ARCHITECTURE.md
MACHINE_DETAIL.md
```

Crear:

```text
docs/REPLENISHMENT.md
docs/adr/ADR-007-replenishment-creation.md
```

---

# 37. `REPLENISHMENT.md`

Debe documentar:

## Purpose

Crear una sesión de reposición para una máquina seleccionada.

## Preconditions

```text
Authenticated Session
Current Operator
Current Machine
```

## API

Documentar el endpoint real:

```text
POST /api/v1/replenishments
```

incluyendo:

* request;
* response;
* status codes;
* authentication;
* idempotency.

## Flow

```text
Operator
   ↓
Machine
   ↓
Start replenishment
   ↓
POST /replenishments
   ↓
Replenishment
```

## Lifecycle

En este commit solamente:

```text
Create
 ↓
Initial backend state
```

Los estados posteriores serán documentados cuando se implementen completion/cancellation.

## Inventory

Explicar explícitamente:

```text
Creating a replenishment does not modify inventory.
```

## Security

Documentar que:

* operador proviene de sesión;
* tenant proviene del backend/session context;
* máquina proviene del contexto seleccionado;
* backend valida autorización.

---

# 38. ADR-007

Título:

```text
ADR-007 — Replenishment Creation Boundary
```

## Context

Después de identificar una máquina, el operador necesita iniciar una operación de reposición.

La reposición debe convertirse en una entidad backend antes de agregar productos.

## Decision

VendingApp crea la reposición mediante la API pública de NexoVending.

```text
Current Machine
      ↓
POST /replenishments
      ↓
Current Replenishment
```

NexoVending es autoridad para:

* operador;
* tenant;
* máquina;
* autorización;
* estado de reposición;
* persistencia;
* futuras operaciones de inventario.

## Consequences

La aplicación:

* mantiene un contexto de reposición;
* no modifica inventario;
* no crea líneas automáticamente;
* no fabrica estados backend;
* no determina autorización.

---

# 39. Actualización de `ARCHITECTURE.md`

Agregar:

```text
Google Identity
      ↓
Session JWT
      ↓
Vending Operator
      ↓
Current Machine
      ↓
Current Replenishment
      ↓
Replenishment Lines
      ↓
Completion
      ↓
Backend Inventory Transaction
```

Debe quedar explícitamente separado:

```text
Create Replenishment
        ≠
Inventory Movement
```

---

# 40. Actualización de README

Actualizar:

```text
Authentication          ✅
Vending Session         ✅
Operator Bootstrap      ✅
Machine Identification  ✅
Machine Detail          ✅
Machine Slots           ✅
Replenishment Creation  ✅
Product Lookup          ⏳
Replenishment Lines     ⏳
Review                  ⏳
Completion              ⏳
Cancellation            ⏳
```

---

# 41. Criterios de aceptación

El Commit 8 se acepta cuando:

## 41.1 Preconditions

* [ ] Existe sesión autenticada.
* [ ] Existe operador Vending.
* [ ] Existe máquina seleccionada.
* [ ] No se permite iniciar reposición sin estos contextos.

## 41.2 Creation

* [ ] Se puede crear una reposición.
* [ ] Se utiliza la máquina actualmente seleccionada.
* [ ] El endpoint coincide con el contrato.
* [ ] La respuesta se mapea correctamente.
* [ ] Se crea `Current Replenishment`.

## 41.3 Authentication

* [ ] Se utiliza Session JWT.
* [ ] Authorization se gestiona mediante ApiClient.
* [ ] Google id_token nunca se envía.

## 41.4 Authorization

* [ ] Backend determina autorización.
* [ ] Flutter no replica permisos.
* [ ] Flutter no selecciona tenant arbitrariamente.
* [ ] Flutter no fabrica operator_id.

## 41.5 Idempotency

* [ ] Double tap no genera múltiples operaciones.
* [ ] Retry respeta el mecanismo de idempotencia contractual.
* [ ] No se crean reposiciones duplicadas por retry.

## 41.6 Context

* [ ] Current Replenishment corresponde a Current Machine.
* [ ] No se mezclan reposiciones entre máquinas.
* [ ] Stale responses no corrompen el contexto.

## 41.7 Inventory

* [ ] Crear reposición no modifica inventario.
* [ ] No existe ledger local.
* [ ] No se descuenta stock.

## 41.8 UI

* [ ] Existe acción Start replenishment.
* [ ] Existe loading state.
* [ ] Existe success state.
* [ ] Existe error state.
* [ ] Existe retry.
* [ ] El botón se deshabilita durante creación.

## 41.9 Tests

* [ ] Unit tests completos.
* [ ] Context tests completos.
* [ ] Double-tap tests.
* [ ] Idempotency tests.
* [ ] Stale response tests.
* [ ] HTTP integration tests.
* [ ] Widget tests.
* [ ] Security tests.
* [ ] Regression suite completa.

## 41.10 Calidad

* [ ] `dart format` pasa.
* [ ] `flutter analyze` pasa.
* [ ] `flutter test` pasa.
* [ ] No existen secretos.
* [ ] No existen tokens en logs.

## 41.11 Documentation

* [ ] README actualizado.
* [ ] ARCHITECTURE actualizado.
* [ ] MACHINE_DETAIL actualizado.
* [ ] REPLENISHMENT creado.
* [ ] ADR-007 creado.

---

# 42. Definition of Done

## Código

* [ ] `Replenishment` implementado.
* [ ] `ReplenishmentService` implementado.
* [ ] `ApiReplenishmentService` implementado.
* [ ] Replenishment state/controller implementado.
* [ ] Current Replenishment Context implementado.
* [ ] UI de inicio implementada.
* [ ] Dependency injection actualizada.

## Integración

* [ ] Machine Context es utilizado correctamente.
* [ ] Operator Context es respetado.
* [ ] Session JWT es utilizado.
* [ ] ApiClient gestiona Authorization.
* [ ] Request ID es gestionado centralmente.
* [ ] Idempotencia sigue el contrato vigente.

## Seguridad

* [ ] No se registran tokens.
* [ ] No se envía Google id_token.
* [ ] No se fabrica operator_id.
* [ ] No se fabrica tenant_id.
* [ ] No se almacenan credenciales en la entidad.

## Business boundary

* [ ] No se agregan líneas automáticamente.
* [ ] No se consultan productos.
* [ ] No se modifica inventario.
* [ ] No se descuenta stock.
* [ ] No se decide autorización en Flutter.

## Tests

* [ ] Unit tests verdes.
* [ ] Integration tests verdes.
* [ ] Widget tests verdes.
* [ ] Security tests verdes.
* [ ] Idempotency tests verdes.
* [ ] Stale response tests verdes.
* [ ] Toda la suite anterior continúa verde.

## Documentación

* [ ] `REPLENISHMENT.md` completo.
* [ ] `ADR-007` completo.
* [ ] README actualizado.
* [ ] ARCHITECTURE actualizado.

---

# 43. Resultado esperado

Al finalizar el Commit 8, VendingApp debe alcanzar:

```text
┌──────────────────────┐
│ Google Sign-In       │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ Session JWT          │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ Vending Operator     │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ Current Machine      │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ Replenishment        │
└──────────┬───────────┘
           ↓
       lines = []
```

La reposición ya existe en NexoVending, pero todavía no contiene productos.

El siguiente commit será:

```text
feat(mobile): implement barcode product lookup
```

y su responsabilidad será exclusivamente resolver:

```text
Barcode
   ↓
NexoVending
   ↓
Product
```

sin agregar todavía la línea de reposición.
