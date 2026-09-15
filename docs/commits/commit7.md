# Commit 7 — Implementar detalle de máquina y slots

**Commit:**

```text
feat(mobile): implement machine detail and slots
```

---

# 1. Objetivo

Implementar la consulta y presentación del **detalle de una máquina** y de sus **slots físicos configurados**, utilizando exclusivamente la API pública de NexoVending.

Flujo:

```text
Authenticated Session
        ↓
Vending Operator
        ↓
Machine identified
        ↓
Load Machine Detail
        ↓
Load Machine Slots
        ↓
Machine Context
        +
Physical Slot Configuration
        ↓
Ready for replenishment flow
```

Este commit convierte la máquina seleccionada en un contexto operacional suficientemente rico para que los siguientes commits puedan construir el flujo de reposición.

---

# 2. Decisión arquitectónica principal

La aplicación debe respetar el modelo definido por NexoVending:

```text
MachineSlot = physical position/container
```

Un slot **no debe modelarse en Flutter como un SKU fijo** ni como una categoría rígida.

Por lo tanto, VendingApp no debe implementar reglas como:

```text
snack machine → slots obligatorios
coffee machine → no slots
mixed machine → determinados slots
```

La existencia, configuración y uso de slots viene determinada por NexoVending.

El móvil únicamente:

1. consulta la configuración;
2. la presenta;
3. mantiene el contexto;
4. posteriormente permitirá seleccionar el slot cuando corresponda.

---

# 3. Alcance

## Incluye

* Modelo `MachineDetail`.
* Modelo `MachineSlot`.
* Servicio de detalle de máquina.
* Servicio de slots.
* Consulta de configuración física.
* Estado de carga.
* Manejo de errores.
* Presentación de máquina.
* Presentación de slots.
* Selección visual de slot.
* Contexto de máquina actualizado.
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
Replenishment creation
Replenishment lines
Inventory changes
Stock deduction
Replenishment completion
Replenishment cancellation
GPS capture
Offline synchronization
```

Tampoco debe implementarse todavía la lógica que decide si una línea de reposición **requiere** slot.

---

# 4. API

Utilizar los endpoints definidos en el contrato HTTP vigente de NexoVending.

Conceptualmente:

```http
GET /api/v1/machines/{machine_id}
Authorization: Bearer <session-jwt>
```

y:

```http
GET /api/v1/machines/{machine_id}/slots
Authorization: Bearer <session-jwt>
```

Los paths, parámetros y payloads exactos deben corresponder al contrato vigente.

No inventar endpoints alternativos.

Si el contrato actual entrega detalle y slots en una única respuesta, la implementación debe respetar esa forma en lugar de introducir artificialmente dos llamadas.

---

# 5. Dependencia del Commit 6

Commit 6 estableció:

```text
Current Machine
```

Commit 7 consume ese contexto.

Flujo:

```text
Machine Identification
        ↓
Current Machine.id
        ↓
Machine Detail
        ↓
Machine Slots
```

No volver a solicitar al usuario el identificador de la máquina si ya existe una máquina válida en contexto.

---

# 6. Modelos

## 6.1 `MachineDetail`

Crear un modelo específico para la información de detalle retornada por NexoVending.

Conceptualmente:

```dart
class MachineDetail {
  final String id;
  final String name;
  final String? code;
  final String? type;
  final String? status;
}
```

Los campos exactos deben corresponder al contrato real.

No duplicar información si la arquitectura existente permite extender correctamente el modelo `Machine`.

La decisión debe favorecer un modelo claro:

```text
Machine
    ↓
MachineDetail
```

si existe una diferencia real entre identificación y detalle.

---

# 7. Modelo `MachineSlot`

Crear:

```text
features/machine/domain/entities/machine_slot.dart
```

Conceptualmente:

```dart
class MachineSlot {
  final String id;
  final String identifier;
  final String? preferredProductId;
  final int? capacity;
  final num? sellingPrice;
}
```

Los campos exactos deben seguir el contrato de NexoVending.

El modelo debe reflejar que:

```text
preferredProduct ≠ actual loaded product
```

si esa distinción está presente en el backend.

No convertir:

```text
preferred_product_id
```

en:

```text
current_product_id
```

sin que el contrato lo establezca.

---

# 8. Capacidad

La capacidad del slot debe tratarse como información proporcionada por backend.

Flutter **no debe calcular ni asumir**:

```text
capacity = fixed constant
```

ni:

```text
slot capacity based on machine type
```

La aplicación debe mostrar el valor configurado por NexoVending cuando corresponda.

Esto mantiene compatible la aplicación con cambios físicos de configuración.

---

# 9. Producto preferido

Si el contrato proporciona:

```text
preferred_product
```

o:

```text
preferred_product_id
```

la aplicación puede presentarlo como:

```text
Producto preferido
```

pero debe evitar expresiones que impliquen que el slot está permanentemente reservado para ese SKU.

Semánticamente:

```text
preferred product
        ≠
required product
```

---

# 10. Slot y producto actual

El detalle de la máquina no debe asumir que el producto preferido es necesariamente el producto actualmente cargado.

El flujo futuro permitirá:

```text
configured slot
       ↓
actual replenishment decision
       ↓
loaded product
```

Por lo tanto, este commit solamente presenta la configuración conocida por backend.

---

# 11. Machine Detail Service

Crear:

```dart
abstract interface class MachineDetailService {
  Future<MachineDetail> getMachineDetail(String machineId);
}
```

Implementación:

```text
ApiMachineDetailService
```

Debe utilizar el `ApiClient` autenticado.

No debe:

* construir Authorization;
* consultar SecureStorage directamente;
* resolver tenant;
* determinar permisos;
* crear máquinas.

---

# 12. Slot Service

Crear:

```dart
abstract interface class MachineSlotService {
  Future<List<MachineSlot>> getSlots(String machineId);
}
```

Implementación:

```text
ApiMachineSlotService
```

Responsabilidades:

* solicitar los slots;
* mapearlos;
* devolver una colección;
* propagar errores.

No debe determinar:

```text
qué slot debería usar el operador
```

Eso pertenece al flujo de reposición posterior.

---

# 13. Carga de detalle y slots

La carga puede realizarse:

```text
Machine Detail
       +
Machine Slots
```

de manera secuencial o concurrente, dependiendo del contrato.

Si son endpoints independientes, se recomienda carga concurrente:

```text
              ┌── GET machine detail
Machine ──────┤
              └── GET machine slots
```

Esto evita latencia innecesaria.

Sin embargo, si el backend requiere primero resolver el detalle antes de consultar slots, respetar esa dependencia.

---

# 14. Estado

Crear un estado explícito para la pantalla:

```text
Initial
Loading
Loaded
Failure
```

`Loaded` debe contener:

```text
MachineDetail
List<MachineSlot>
```

Conceptualmente:

```text
MachineScreenState
    ├── loading
    ├── detail
    ├── slots
    └── error
```

No mantener múltiples estados parcialmente inconsistentes.

---

# 15. Estado parcial

Si detalle y slots son dos requests independientes, definir explícitamente qué ocurre si:

```text
Machine Detail → success
Slots → failure
```

Para V1 se recomienda que la pantalla completa permanezca en:

```text
Failure
```

cuando la configuración de slots sea necesaria para continuar al flujo operacional.

No presentar una máquina como completamente cargada si su configuración física requerida todavía no está disponible.

---

# 16. Machine Context

Actualizar el contexto de máquina para contener:

```text
Current Machine
Current Machine Detail
Current Machine Slots
```

Conceptualmente:

```text
MachineContext
├── machine
├── detail
└── slots
```

Sin embargo, evitar duplicación innecesaria.

Si `MachineDetail` ya contiene todos los datos básicos de `Machine`, utilizar una única representación enriquecida.

El objetivo es evitar:

```text
machine A
machineDetail B
```

representando estados diferentes de la misma máquina.

---

# 17. Selección de slot

La UI puede permitir seleccionar visualmente un slot.

Por ejemplo:

```text
Machine
ABC-001

Slots

[ A01 ]  Producto preferido
[ A02 ]  Producto preferido
[ A03 ]  Vacío
[ A04 ]  Producto preferido
```

La selección debe ser únicamente:

```text
selectedSlotId
```

No debe modificar:

* inventario;
* capacidad;
* precio;
* producto;
* configuración de máquina.

La selección se consumirá en los commits posteriores.

---

# 18. Regla importante sobre slots

El móvil **no debe filtrar slots según tipo de máquina**.

Incorrecto:

```dart
if (machine.type == MachineType.snack) {
  showSnackSlots();
}
```

También incorrecto:

```dart
if (machine.type == MachineType.coffee) {
  hideSlots();
}
```

Correcto:

```text
NexoVending
      ↓
configured slots
      ↓
VendingApp displays configured slots
```

La configuración física es autoridad del backend.

---

# 19. Orden de slots

Si el backend proporciona:

```text
position
sequence
code
```

la aplicación debe respetar el orden establecido por backend.

No ordenar arbitrariamente por:

```text
slot.id
```

si el contrato define otro orden.

Si el contrato no define orden, documentar el criterio utilizado.

---

# 20. Empty state

Una máquina puede retornar:

```text
slots = []
```

Esto no debe interpretarse automáticamente como error.

Mostrar:

```text
No slots configured
```

siempre que el contrato permita una máquina sin slots.

No crear slots localmente.

No asumir que la ausencia de slots implica una máquina de café.

---

# 21. UI

Crear:

```text
MachineDetailPage
```

Debe presentar:

```text
Machine
────────────────
Name
Code
Type
Status
```

y:

```text
Physical configuration
───────────────────────
Slots
```

Cada slot puede mostrar:

```text
Identifier
Capacity
Preferred product
Selling price
```

solamente cuando esos datos formen parte del contrato.

---

# 22. Loading UI

Mientras se carga:

```text
Loading machine...
Loading configuration...
```

Se recomienda evitar múltiples indicadores independientes si esto produce una experiencia confusa.

Preferentemente:

```text
Loading machine configuration...
```

---

# 23. Error UI

Mostrar mensajes diferenciados para:

### 401

```text
Your session has expired.
```

### 403

```text
You do not have access to this machine.
```

### 404

```text
Machine not found.
```

### Network

```text
Unable to load machine configuration.
```

### 5xx

```text
The machine configuration is temporarily unavailable.
```

Con:

```text
Retry
```

cuando corresponda.

---

# 24. Navegación

El flujo de navegación debe ser:

```text
Operator
   ↓
Machine identification
   ↓
Machine detail
   ↓
Machine slots
```

En este commit, la pantalla de máquina se convierte en el nuevo punto de entrada hacia la futura operación.

No implementar todavía:

```text
Machine
   ↓
Create replenishment
```

Eso corresponde a Commit 8.

---

# 25. Tests unitarios

## 25.1 Machine detail success

Verificar que:

* se llama al endpoint correcto;
* se utiliza machine ID;
* el JSON se transforma correctamente.

---

## 25.2 Slots success

Verificar:

* lista correctamente deserializada;
* orden preservado;
* campos opcionales manejados.

---

## 25.3 Empty slots

Debe devolver:

```text
[]
```

sin producir excepción.

---

## 25.4 Invalid machine ID

No ejecutar HTTP cuando el identificador sea claramente inválido según el contrato.

---

## 25.5 401

Debe propagarse como error de sesión.

---

## 25.6 403

Debe propagarse como acceso denegado.

---

## 25.7 404

Debe propagarse como máquina no encontrada.

---

## 25.8 5xx

Debe permitir recuperación mediante retry.

---

## 25.9 Timeout

Debe utilizar:

```text
TimeoutException
```

existente.

---

## 25.10 Network failure

Debe utilizar:

```text
NetworkException
```

existente.

---

# 26. Tests de Machine Context

Verificar:

```text
Machine selected
      ↓
Detail loaded
      ↓
Slots loaded
      ↓
Context complete
```

Debe comprobarse que:

* el contexto contiene la máquina correcta;
* los slots corresponden a esa máquina;
* no se mezclan datos entre máquinas.

Caso importante:

```text
Machine A
 ↓
load A

Machine B
 ↓
load B
```

Debe terminar:

```text
Current Machine = B
Current Slots = B.slots
```

Nunca:

```text
Machine B
Slots A
```

---

# 27. Tests de concurrencia lógica

Si detalle y slots se cargan concurrentemente, probar:

```text
detail success
slots success
```

y:

```text
detail success
slots failure
```

También:

```text
detail failure
slots success
```

La UI debe terminar en un estado coherente.

No permitir que una respuesta tardía de una solicitud anterior sobrescriba el contexto de una máquina nueva.

---

# 28. Tests de stale response

Este test es importante.

Escenario:

```text
resolve Machine A
      ↓
request detail A

operator selects Machine B
      ↓
request detail B

response A arrives late
```

La respuesta de A no debe sobrescribir:

```text
Current Machine = B
```

El controller debe validar que la respuesta corresponde al contexto actual antes de aplicar el resultado.

---

# 29. Tests de integración HTTP

Crear pruebas para:

```http
GET /api/v1/machines/{machine_id}
```

y:

```http
GET /api/v1/machines/{machine_id}/slots
```

Verificar:

* Authorization Bearer;
* machine ID correcto;
* no Google id_token;
* request ID;
* respuesta;
* serialización;
* errores.

---

# 30. Tests de integración del flujo

Probar:

```text
Authenticated session
        ↓
Current operator
        ↓
Current machine
        ↓
Machine detail
        ↓
Machine slots
```

No se necesita un backend real de PostgreSQL en VendingApp para estos tests HTTP.

La base de datos y reglas de autoridad pertenecen a NexoVending.

El objetivo del test móvil es validar el **contrato HTTP**.

---

# 31. Tests widget

## 31.1 Loading

Debe mostrar estado de carga.

## 31.2 Machine detail

Debe mostrar la información disponible.

## 31.3 Slots

Debe renderizar todos los slots retornados.

## 31.4 Empty slots

Debe mostrar empty state.

## 31.5 Slot selection

Debe permitir seleccionar un slot sin modificar el backend.

## 31.6 Error

Debe mostrar mensaje y retry.

## 31.7 401

Debe volver al flujo de sesión.

## 31.8 403

Debe mostrar acceso denegado.

## 31.9 Stale response

Una respuesta antigua no debe modificar la pantalla de la máquina actual.

---

# 32. Tests de seguridad

Verificar:

* JWT no aparece en logs;
* Authorization no aparece en logs;
* Google `id_token` nunca se envía;
* machine ID no permite modificar tenant;
* datos de slot no pueden modificar configuración;
* selección de slot no ejecuta operaciones backend.

---

# 33. Documentación

Actualizar:

```text
README.md
ARCHITECTURE.md
MACHINE_IDENTIFICATION.md
```

Crear:

```text
docs/MACHINE_DETAIL.md
docs/adr/ADR-006-machine-detail-and-slots.md
```

---

# 34. `MACHINE_DETAIL.md`

Debe documentar:

## Purpose

Consulta y presentación de la configuración de una máquina.

## API

Documentar los endpoints reales del contrato.

## Machine Detail

Explicar qué información representa.

## Machine Slot

Explicar explícitamente:

```text
MachineSlot represents a physical position/container.
```

y:

```text
It is not a fixed SKU assignment.
```

## Slot semantics

Documentar:

* identifier;
* capacity;
* preferred product;
* selling price;
* cualquier otro campo realmente presente en el contrato.

## Empty slots

Explicar que:

```text
slots = []
```

no necesariamente representa un error.

## Error handling

Documentar 401/403/404/5xx/network.

## State management

Documentar:

```text
Initial
Loading
Loaded
Failure
```

## Security

Documentar que NexoVending mantiene autoridad sobre:

* tenant;
* máquina;
* acceso;
* configuración física.

---

# 35. ADR-006

Título:

```text
ADR-006 — Machine Detail and Physical Slot Representation
```

## Context

Una vez identificada una máquina, VendingApp necesita conocer su configuración física antes de iniciar operaciones de reposición.

La configuración puede variar entre:

```text
snack machines
coffee machines
mixed machines
```

y no debe codificarse como reglas rígidas en el cliente.

## Decision

VendingApp consumirá la configuración proporcionada por NexoVending.

Los slots se tratarán como:

```text
physical positions/containers
```

y no como asignaciones rígidas de SKU.

## Consequences

El móvil:

* presenta los slots configurados;
* conserva su selección;
* no decide su existencia;
* no determina capacidad;
* no determina producto preferido;
* no modifica configuración.

NexoVending continúa siendo autoridad.

---

# 36. Actualización de `ARCHITECTURE.md`

El flujo debe quedar representado como:

```text
Google Identity
      ↓
NexoVending Session
      ↓
Vending Operator
      ↓
Current Machine
      ↓
Machine Detail
      ↓
Physical Slots
      ↓
Future Replenishment
```

Y:

```text
MachineSlot
     │
     ├── physical position
     ├── capacity
     ├── preferred product
     └── selling price
```

No:

```text
MachineSlot
     ↓
Fixed SKU
```

---

# 37. Actualización de README

Actualizar estado:

```text
Authentication          ✅
Vending Session         ✅
Operator Bootstrap      ✅
Machine Identification  ✅
Machine Detail          ✅
Machine Slots           ✅
Replenishment           ⏳
```

---

# 38. Criterios de aceptación

El commit se acepta cuando:

## 38.1 Machine Detail

* [ ] La máquina seleccionada puede cargar su detalle.
* [ ] El endpoint coincide con el contrato vigente.
* [ ] El modelo representa correctamente la respuesta.
* [ ] No se inventan campos.

## 38.2 Slots

* [ ] Los slots configurados pueden cargarse.
* [ ] Se preserva su información relevante.
* [ ] Se preserva el orden definido por backend.
* [ ] `slots = []` se maneja correctamente.
* [ ] No se crean slots localmente.

## 38.3 Slot semantics

* [ ] `MachineSlot` se trata como posición/contenedor físico.
* [ ] No se asocia rígidamente a un SKU.
* [ ] `preferred_product` no se interpreta como producto obligatorio.
* [ ] Capacity proviene de backend.
* [ ] No se implementan reglas snack/coffee específicas.

## 38.4 Context

* [ ] Current Machine permanece coherente.
* [ ] Detail corresponde a Current Machine.
* [ ] Slots corresponden a Current Machine.
* [ ] No pueden mezclarse datos de máquinas distintas.
* [ ] Stale responses no sobrescriben el contexto actual.

## 38.5 Authentication

* [ ] Todas las llamadas utilizan Session JWT.
* [ ] Authorization se gestiona por ApiClient.
* [ ] Google id_token no se envía.
* [ ] 401 invalida correctamente la sesión.

## 38.6 Authorization

* [ ] NexoVending es autoridad sobre acceso a máquina.
* [ ] Flutter no replica autorización.
* [ ] Flutter no selecciona tenant arbitrariamente.

## 38.7 UI

* [ ] Existe pantalla de detalle.
* [ ] Existe estado loading.
* [ ] Existe estado error.
* [ ] Existe empty state para slots.
* [ ] Puede seleccionarse visualmente un slot.
* [ ] Seleccionar un slot no modifica backend.

## 38.8 Tests

* [ ] Unit tests.
* [ ] Context tests.
* [ ] HTTP integration tests.
* [ ] Widget tests.
* [ ] Stale response tests.
* [ ] Security tests.
* [ ] Regression tests.

## 38.9 Calidad

* [ ] `dart format` pasa.
* [ ] `flutter analyze` pasa.
* [ ] `flutter test` pasa.
* [ ] No existen warnings críticos.
* [ ] No existen secretos en código.

## 38.10 Documentación

* [ ] README actualizado.
* [ ] ARCHITECTURE actualizado.
* [ ] MACHINE_IDENTIFICATION actualizado.
* [ ] MACHINE_DETAIL creado.
* [ ] ADR-006 creado.

---

# 39. Definition of Done

## Código

* [ ] `MachineDetail` implementado.
* [ ] `MachineSlot` implementado.
* [ ] `MachineDetailService` implementado.
* [ ] `MachineSlotService` implementado.
* [ ] Controller/state implementado.
* [ ] Machine context actualizado.
* [ ] UI implementada.
* [ ] Dependency injection actualizada.

## API

* [ ] Endpoint(s) correctos.
* [ ] Bearer token gestionado centralmente.
* [ ] Request ID presente.
* [ ] Serialización correcta.
* [ ] Errores correctamente mapeados.

## Arquitectura

* [ ] VendingApp continúa dependiendo exclusivamente de NexoVending HTTP.
* [ ] No se importa Nexo Platform directamente.
* [ ] No se replica lógica de backend.
* [ ] No se implementan reglas de slots en cliente.
* [ ] No se implementan reglas de reposición.

## Seguridad

* [ ] JWT nunca aparece en logs.
* [ ] Google id_token nunca aparece en logs.
* [ ] Authorization nunca aparece en logs.
* [ ] Slot selection no modifica backend.

## Tests

* [ ] Unit tests completos.
* [ ] Integration tests completos.
* [ ] Widget tests completos.
* [ ] Security tests completos.
* [ ] Stale response test completo.
* [ ] Suite anterior completamente verde.

## Documentación

* [ ] Documentación técnica actualizada.
* [ ] ADR-006 creado.
* [ ] Semántica de `MachineSlot` documentada explícitamente.

---

# 40. Resultado esperado

Al finalizar el Commit 7:

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
│ Machine Detail       │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ Physical Slots       │
└──────────────────────┘
```

La aplicación queda preparada para iniciar el flujo de reposición.

El siguiente commit será:

```text
feat(mobile): implement replenishment creation
```

y deberá utilizar el `Operator + Machine + Slot configuration` ya establecido, sin volver a resolver ninguna de estas responsabilidades.
