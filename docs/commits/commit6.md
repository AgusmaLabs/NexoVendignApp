# Commit 6 — Implementar identificación de máquina

**Commit:**

```text
feat(mobile): implement machine identification
```

## 1. Objetivo

Implementar en VendingApp el flujo para que un operador autenticado pueda **identificar una máquina de vending** utilizando la API pública de NexoVending.

Flujo:

```text
Authenticated Session
        ↓
Vending Operator
        ↓
Identify Machine
        ↓
Resolve Machine
        ↓
Machine identified
        ↓
Ready for machine detail / slots
```

El objetivo de este commit es establecer la máquina actualmente seleccionada como contexto operacional de la aplicación.

Este commit **no implementa todavía**:

* detalle completo de máquina;
* slots;
* productos;
* barcode scanning;
* reposición;
* inventario;
* ubicación/GPS;
* creación de replenishment;
* líneas de reposición;
* completion/cancellation;
* lógica offline.

---

# 2. Alcance

## Incluye

* Modelo `Machine`.
* Servicio `MachineService`.
* Endpoint de resolución de máquina.
* Input para identificación de máquina.
* Estado de máquina seleccionada.
* Validación básica de entrada.
* Manejo de errores HTTP.
* UI mínima de identificación.
* Contexto de máquina seleccionada.
* Tests unitarios.
* Tests de integración HTTP.
* Tests widget.
* Documentación.

## No incluye

No agregar en este commit:

```text
MachineDetailService
SlotService
ProductService
ReplenishmentService
InventoryService
LocationService
BarcodeScanner
```

Aunque `LocationService` y `BarcodeScanner` ya existan como abstracciones desde Commit 2, **todavía no deben conectarse al flujo**.

---

# 3. Contrato HTTP

La identificación debe utilizar el endpoint público de NexoVending definido en el contrato móvil vigente:

```http
GET /api/v1/machines/resolve
Authorization: Bearer <session-jwt>
```

Los parámetros exactos deben corresponder al contrato vigente de NexoVending.

Por ejemplo, conceptualmente:

```text
machine identifier
        ↓
GET /api/v1/machines/resolve
        ↓
Machine
```

No inventar parámetros, nombres de campos ni códigos de respuesta.

La implementación debe tomar como fuente de verdad:

```text
Mobile API Contract — NexoVending
```

---

# 4. Responsabilidades

La separación debe ser:

```text
UI
 ↓
Machine Identification Controller
 ↓
MachineService
 ↓
Authenticated ApiClient
 ↓
NexoVending API
```

La UI únicamente captura el identificador.

NexoVending determina:

* si la máquina existe;
* a qué tenant pertenece;
* si el operador puede acceder;
* cuál es su configuración;
* cuál es su estado.

VendingApp no debe replicar estas reglas.

---

# 5. Modelo `Machine`

Crear:

```text
features/machine/domain/entities/machine.dart
```

El modelo debe representar únicamente la información necesaria para identificar y presentar la máquina en este commit.

Conceptualmente:

```dart
class Machine {
  final String id;
  final String name;
  final String? code;
  final String? type;
}
```

Los campos reales deben corresponder exactamente al contrato vigente.

No asumir que:

```text
machine.type == snack
```

implica determinadas reglas de slots.

El modelo debe mantenerse neutral respecto de las reglas físicas.

---

# 6. MachineService

Crear:

```dart
abstract interface class MachineService {
  Future<Machine> resolveMachine(String identifier);
}
```

Implementación:

```text
ApiMachineService
```

Responsabilidades:

1. recibir identificador;
2. validar que tenga formato permitido;
3. llamar al endpoint de resolución;
4. mapear la respuesta;
5. devolver `Machine`;
6. propagar errores mediante la infraestructura existente.

No debe:

* consultar directamente SecureStorage;
* construir Authorization headers;
* resolver tenant;
* verificar permisos localmente;
* crear máquinas;
* consultar slots.

---

# 7. Identificador de máquina

El usuario debe poder introducir un identificador de máquina.

La aplicación debe permitir el identificador definido por NexoVending.

La validación móvil debe ser únicamente de calidad de entrada:

```text
empty
whitespace
obvious invalid format
```

No duplicar reglas de negocio del backend.

Por ejemplo, evitar:

```dart
if (machineCode.startsWith("VM-")) {
  ...
}
```

si esa restricción no forma parte explícita del contrato.

El backend continúa siendo la autoridad.

---

# 8. Estado de identificación

Crear un estado explícito:

```text
Initial
Resolving
Resolved
Failure
```

Conceptualmente:

```text
Initial
   ↓
Resolving
   ↓
Resolved
```

o:

```text
Resolving
   ↓
Failure
   ↓
Retry
   ↓
Resolving
```

No utilizar `null` como sustituto de una máquina seleccionada o como mecanismo general de estado.

---

# 9. Machine Context

Una vez resuelta correctamente la máquina, VendingApp debe mantenerla como:

```text
Current Machine
```

durante el flujo operacional.

Conceptualmente:

```text
Operator Context
       +
Machine Context
       ↓
Future vending operations
```

La máquina seleccionada debe ser un estado de aplicación, no una variable aislada dentro de un widget.

Esto permitirá que los siguientes commits consuman el contexto:

```text
Machine
  ↓
Machine Detail
  ↓
Slots
  ↓
Replenishment
```

---

# 10. Persistencia

No persistir la máquina seleccionada como autoridad.

En V1, la selección puede ser:

```text
in-memory application state
```

Si posteriormente se requiere recordar la última máquina utilizada, deberá tratarse explícitamente como una preferencia/caché y nunca como autoridad.

No almacenar:

* JWT;
* credenciales;
* permisos;
* información sensible de la máquina.

---

# 11. UI

Crear una pantalla mínima:

```text
Identify Machine
```

Debe contener:

```text
Machine identifier
[_____________________]

[Identify machine]
```

Durante la consulta:

```text
Resolving machine...
```

Después de éxito:

```text
Machine identified

<Machine name>
<Machine identifier>
```

Debe existir una acción para continuar al siguiente paso.

Todavía no debe navegar a una pantalla de slots si Commit 7 aún no está implementado.

Puede utilizarse un placeholder:

```text
Machine identified
Ready for machine details
```

---

# 12. Errores

Utilizar las excepciones definidas por la infraestructura de Commit 2.

## 401 Unauthorized

La sesión ya no es válida.

Flujo:

```text
Machine request
      ↓
401
      ↓
Session expired
      ↓
Authentication flow
```

No intentar resolver nuevamente con un token inválido.

---

## 403 Forbidden

El operador está autenticado pero no tiene acceso a la máquina.

Mostrar:

```text
You do not have access to this machine.
```

No ocultar el error convirtiéndolo en "machine not found".

---

## 404 Not Found

La máquina no existe o no puede ser resuelta según el contrato.

Mostrar:

```text
Machine not found.
```

Permitir:

```text
Retry / Enter another identifier
```

---

## 409 Conflict

Si el contrato utiliza `409` para algún estado específico de resolución, mapearlo según el contrato.

No inventar semántica en Flutter.

---

## 422 Validation Error

Mostrar un error de entrada comprensible.

El detalle exacto debe seguir el contrato de NexoVending.

---

## 5xx

Mostrar:

```text
We couldn't load the machine right now.
```

y permitir reintentar.

---

## Network / Timeout

Utilizar:

```text
NetworkException
TimeoutException
```

ya definidos.

No crear un segundo sistema de errores.

---

# 13. Autenticación

La llamada debe utilizar la sesión creada en Commit 4.

Flujo:

```text
Google Sign-In
      ↓
Session JWT
      ↓
Operator
      ↓
MachineService
      ↓
Authenticated ApiClient
      ↓
GET /machines/resolve
```

La feature no debe conocer:

```text
Google id_token
```

El `id_token` no debe enviarse al endpoint de máquinas.

Únicamente debe utilizarse:

```http
Authorization: Bearer <session-jwt>
```

---

# 14. Tenant boundary

VendingApp no debe enviar un `tenant_id` a la API de máquinas salvo que el contrato específico de resolución lo exija.

La autoridad debe continuar siendo:

```text
Session JWT
        ↓
NexoVending
        ↓
Tenant context
        ↓
Machine authorization
```

No permitir:

```text
Machine identifier + arbitrary tenant_id
```

como mecanismo de selección de tenant desde Flutter.

---

# 15. Seguridad

Debe verificarse que:

* JWT no aparece en logs;
* Google `id_token` no aparece en logs;
* Authorization header no aparece en logs;
* errores HTTP no imprimen credenciales;
* machine context no contiene tokens;
* la UI no permite seleccionar arbitrariamente un tenant;
* no se almacena información sensible innecesaria.

---

# 16. Tests unitarios

## 16.1 MachineService — éxito

Given:

```text
valid machine identifier
```

When:

```text
resolveMachine()
```

Then:

```text
Machine is returned
```

Verificar:

* método correcto;
* endpoint correcto;
* parámetros correctos;
* JSON correctamente mapeado.

---

## 16.2 Empty identifier

Debe rechazarse antes de realizar una llamada HTTP.

Verificar:

```text
no HTTP request
```

---

## 16.3 Invalid identifier

Si existe una regla sintáctica explícita en el contrato:

```text
invalid identifier
        ↓
validation failure
```

No realizar HTTP.

No introducir reglas adicionales.

---

## 16.4 401

Debe producir el error de autenticación existente.

---

## 16.5 403

Debe producir el error de acceso correspondiente.

---

## 16.6 404

Debe representar correctamente:

```text
MachineNotFound
```

o la abstracción equivalente definida por la aplicación.

---

## 16.7 422

Debe mapear correctamente el error de validación.

---

## 16.8 5xx

Debe permitir que la UI pueda presentar estado recuperable.

---

## 16.9 Timeout

Debe producir:

```text
TimeoutException
```

---

## 16.10 Network failure

Debe producir:

```text
NetworkException
```

---

# 17. Tests del Machine Context

Verificar:

### Initial

```text
currentMachine == null
```

### Resolved

```text
resolve
   ↓
currentMachine == returned machine
```

### Failure

Una resolución fallida no debe dejar una máquina parcialmente actualizada.

Especialmente:

```text
previous machine
      ↓
failed new resolution
```

Debe definirse y probarse la política seleccionada.

Para V1 se recomienda:

```text
failed identification
      ↓
do not replace existing valid machine context
```

cuando exista una máquina ya seleccionada.

---

# 18. Tests de integración HTTP

Crear tests utilizando el servidor HTTP fake existente.

Verificar:

```http
GET /api/v1/machines/resolve
Authorization: Bearer test-session-jwt
```

Debe verificarse explícitamente:

* método;
* path;
* query/path parameters;
* Authorization;
* ausencia de Google id_token;
* deserialización;
* errores.

Caso principal:

```text
Authenticated session
       ↓
resolve machine
       ↓
200
       ↓
Machine
```

---

# 19. Tests widget

## 19.1 Initial state

Debe mostrar:

```text
Machine identifier
Identify machine
```

---

## 19.2 Empty input

No debe ejecutarse HTTP.

Debe mostrar validación.

---

## 19.3 Loading

Después de presionar:

```text
Identify machine
```

debe mostrarse:

```text
Resolving machine...
```

y evitar solicitudes duplicadas por múltiples taps.

---

## 19.4 Success

Debe mostrar los datos mínimos de la máquina.

---

## 19.5 Not found

Debe mostrar:

```text
Machine not found.
```

y permitir modificar el identificador.

---

## 19.6 Forbidden

Debe mostrar acceso denegado.

---

## 19.7 Network failure

Debe mostrar error recuperable.

---

## 19.8 Retry

Verificar:

```text
Failure
 ↓
Retry
 ↓
Request
 ↓
Success
```

---

## 19.9 401

Verificar que el estado de sesión se invalide y la aplicación vuelva al flujo de autenticación.

---

# 20. Tests de seguridad

Agregar pruebas que aseguren:

```text
Google id_token
    ≠
machine request credential
```

y:

```text
JWT
    → Authorization header only
```

Verificar también que:

* logs no contengan JWT;
* logs no contengan id_token;
* errores no contengan Authorization;
* machine context no persista credenciales.

---

# 21. Tests de regresión

Debe ejecutarse la suite completa de commits anteriores:

```text
flutter analyze
flutter test
```

Los tests existentes de:

* App;
* router;
* configuration;
* networking;
* storage;
* authentication;
* session;
* operator bootstrap

deben continuar pasando.

---

# 22. Documentación

Actualizar:

```text
README.md
ARCHITECTURE.md
SESSION.md
OPERATOR_BOOTSTRAP.md
```

Crear:

```text
docs/MACHINE_IDENTIFICATION.md
docs/adr/ADR-005-machine-identification.md
```

---

# 23. `MACHINE_IDENTIFICATION.md`

Debe documentar:

## Purpose

Identificación de una máquina por un operador autenticado.

## API

Documentar el endpoint real:

```text
GET /api/v1/machines/resolve
```

incluyendo:

* autenticación;
* parámetros;
* respuesta;
* errores;
* ejemplos.

Los ejemplos deben coincidir con el contrato vigente.

## Flow

```text
Operator
   ↓
Machine identifier
   ↓
MachineService
   ↓
Authenticated API
   ↓
NexoVending
   ↓
Machine
```

## State machine

```text
Initial
   ↓
Resolving
   ↓
Resolved
```

o:

```text
Resolving
   ↓
Failure
   ↓
Retry
```

## Security

Documentar que:

* el JWT pertenece al contexto de sesión;
* la identidad de máquina es validada por NexoVending;
* Flutter no decide tenant;
* Flutter no decide autorización.

---

# 24. ADR-005

Título:

```text
ADR-005 — Machine Identification Boundary
```

## Context

Una vez autenticado y resuelto el operador, la aplicación necesita seleccionar la máquina sobre la cual se ejecutarán las operaciones de terreno.

## Decision

VendingApp resuelve la máquina mediante la API pública de NexoVending.

```text
VendingApp
    ↓
GET /api/v1/machines/resolve
    ↓
NexoVending
    ↓
Machine
```

NexoVending permanece como autoridad para:

* existencia;
* tenant;
* asignación;
* acceso;
* configuración.

## Consequences

VendingApp:

* mantiene un contexto temporal de máquina;
* no replica reglas de máquinas;
* no determina acceso;
* no crea máquinas;
* no mantiene un catálogo local de máquinas.

---

# 25. Actualización de `ARCHITECTURE.md`

Agregar:

```text
┌──────────────────────┐
│ Google Authentication│
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ NexoVending Session  │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ Vending Operator     │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ Machine Identification│
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ Current Machine      │
└──────────────────────┘
```

Debe quedar explícito que:

```text
Operator ≠ Machine
```

y que ambos son contextos distintos.

---

# 26. Actualización de README

Actualizar el estado del proyecto:

```text
Authentication       ✅
Vending Session      ✅
Operator Bootstrap   ✅
Machine Identification ✅
Machine Detail       ⏳
Slots                ⏳
Replenishment        ⏳
```

No marcar funcionalidades futuras como implementadas.

---

# 27. Definition of Done

El Commit 6 está terminado únicamente cuando:

## 27.1 Código

* [ ] Modelo `Machine` implementado.
* [ ] `MachineService` implementado.
* [ ] `ApiMachineService` implementado.
* [ ] Machine identification controller/state implementado.
* [ ] UI de identificación implementada.
* [ ] Machine context implementado.
* [ ] Dependency injection actualizada.
* [ ] No existe cliente HTTP paralelo.

## 27.2 API

* [ ] Endpoint correcto implementado.
* [ ] Parámetros corresponden al contrato real.
* [ ] Authorization Bearer es gestionado por `ApiClient`.
* [ ] Google id_token no se utiliza para esta llamada.
* [ ] Respuestas se deserializan correctamente.

## 27.3 Boundary

* [ ] NexoVending es autoridad sobre la máquina.
* [ ] VendingApp no resuelve tenant.
* [ ] VendingApp no replica autorización.
* [ ] VendingApp no crea máquinas.
* [ ] VendingApp no mantiene un catálogo autoritativo.
* [ ] No se introducen reglas de slots.
* [ ] No se introducen reglas de reposición.

## 27.4 Errores

* [ ] 401 correctamente manejado.
* [ ] 403 correctamente manejado.
* [ ] 404 correctamente manejado.
* [ ] 422 correctamente manejado.
* [ ] 5xx correctamente manejado.
* [ ] Timeout correctamente manejado.
* [ ] Network failure correctamente manejado.
* [ ] Retry disponible cuando corresponde.

## 27.5 Tests

* [ ] Unit tests completos.
* [ ] Machine context tests completos.
* [ ] HTTP integration tests completos.
* [ ] Widget tests completos.
* [ ] Security tests completos.
* [ ] Regression suite completa.
* [ ] `flutter analyze` pasa.
* [ ] `flutter test` pasa.
* [ ] `dart format` pasa.

## 27.6 Seguridad

* [ ] JWT no aparece en logs.
* [ ] Google id_token no aparece en logs.
* [ ] Authorization header no aparece en logs.
* [ ] Machine context no almacena credenciales.
* [ ] No existe selección arbitraria de tenant desde la UI.

## 27.7 Documentación

* [ ] README actualizado.
* [ ] ARCHITECTURE actualizado.
* [ ] SESSION actualizado.
* [ ] OPERATOR_BOOTSTRAP actualizado.
* [ ] MACHINE_IDENTIFICATION creado.
* [ ] ADR-005 creado.

---

# 28. Resultado esperado

Al finalizar Commit 6, el flujo funcional será:

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
│ Identify Machine     │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ Current Machine      │
└──────────────────────┘
```

La aplicación queda preparada para el siguiente paso:

```text
Commit 7
feat(mobile): implement machine detail and slots
```

En particular, **no debemos adelantar la lógica de slots a este commit**. Esto es importante porque `MachineSlot` representa un contenedor/posición física configurable y no debe quedar implícitamente ligado a que una máquina sea de snacks, café o mixta.
