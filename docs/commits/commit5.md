# Commit 5 — Implementar bootstrap del operador

**Commit:**

```text
feat(mobile): implement operator bootstrap
```

## 1. Objetivo

Implementar el bootstrap del operador autenticado de VendingApp consumiendo:

```http
GET /api/v1/operators/me
Authorization: Bearer <session-jwt>
```

El objetivo es transformar una sesión autenticada en un **contexto de operador Vending** disponible para la aplicación.

Flujo resultante:

```text
Google Sign-In
      ↓
Google id_token
      ↓
POST /api/v1/auth/session
      ↓
Session JWT
      ↓
SecureStorage
      ↓
GET /api/v1/operators/me
      ↓
Vending Operator
      ↓
Operator Context
```

Este commit **no implementa**:

* máquinas;
* slots;
* productos;
* inventario;
* reposición;
* permisos de negocio adicionales;
* autorización local de operaciones;
* sincronización offline;
* historial.

---

## 2. Alcance

### Incluye

* Modelo de operador móvil.
* `OperatorService`.
* Cliente para `GET /api/v1/operators/me`.
* Estado de bootstrap del operador.
* Persistencia local mínima del contexto del operador, si es necesaria para restauración de UI.
* Integración con la sesión JWT existente.
* Manejo de errores de operador.
* Bootstrap automático después de obtener/restaurar una sesión válida.
* Estado global de operador disponible para las futuras features.
* UI mínima de bootstrap.
* Tests unitarios, de integración HTTP y widget.
* Documentación técnica.

### No incluye

No se debe introducir en este commit:

```text
MachineService
ProductService
ReplenishmentService
InventoryService
LocationService usage
BarcodeScanner usage
```

Tampoco se deben implementar reglas de autorización de negocio en Flutter.

---

# 3. Contrato HTTP

El endpoint consumido es:

```http
GET /api/v1/operators/me
Authorization: Bearer <session-jwt>
```

La aplicación debe utilizar el `ApiClient` autenticado introducido en Commit 4.

No se deben construir manualmente headers de autorización desde la feature.

El flujo debe ser:

```text
OperatorService
    ↓
Authenticated ApiClient
    ↓
Authorization: Bearer <session-jwt>
    ↓
NexoVending
```

---

# 4. Modelo `Operator`

Crear un modelo de dominio/aplicación para representar el operador retornado por NexoVending.

Ejemplo conceptual:

```dart
class Operator {
  final String id;
  final String name;
  final String? email;
  final String? role;
}
```

Los campos exactos deben corresponder al **contrato HTTP vigente de NexoVending**.

No inventar campos que el backend no entregue.

El modelo debe:

* ser inmutable;
* soportar `fromJson`;
* validar los campos obligatorios;
* evitar lógica de negocio;
* ser independiente de widgets.

Si el contrato distingue entre:

```text
operator_id
name
email
role
```

se debe conservar exactamente esa semántica en la capa de mapeo.

---

# 5. `OperatorService`

Crear:

```text
OperatorService
```

Responsabilidad:

```text
obtener el operador autenticado
```

Interfaz conceptual:

```dart
abstract interface class OperatorService {
  Future<Operator> getCurrentOperator();
}
```

Implementación:

```text
ApiOperatorService
```

Debe ejecutar exclusivamente:

```http
GET /api/v1/operators/me
```

No debe:

* resolver tenant;
* interpretar JWT;
* determinar permisos;
* fabricar roles;
* consultar máquinas;
* consultar productos.

La autoridad del operador continúa siendo NexoVending.

---

# 6. Operator Bootstrap

Crear un componente de aplicación responsable del proceso:

```text
Session authenticated
        ↓
Operator bootstrap
        ↓
GET /operators/me
        ↓
Operator available
```

Estados recomendados:

```text
Unknown
Loading
Loaded
Failure
```

Opcionalmente:

```text
Unauthenticated
```

puede mantenerse como estado superior de la sesión, pero no duplicar innecesariamente la máquina de estados de Commit 4.

La arquitectura debe evitar dos fuentes de verdad independientes para autenticación.

---

# 7. Relación con Session

La sesión continúa siendo la autoridad de autenticación.

```text
Session
  └── authenticated JWT

Operator
  └── business identity in NexoVending
```

Conceptualmente:

```text
Session ≠ Operator
```

La existencia de una sesión válida **no implica** que el usuario tenga un operador Vending válido.

Por lo tanto:

```text
Authenticated session
        ↓
Operator bootstrap
        ↓
Operator found
```

es un paso obligatorio antes de permitir acceder al área funcional de Vending.

---

# 8. Bootstrap después de login

Después de completar correctamente Commit 4:

```text
Google authentication
        ↓
Create Vending session
        ↓
Authenticated
        ↓
Load current operator
        ↓
Operator loaded
        ↓
Home/application shell
```

No se debe mostrar la funcionalidad principal de Vending mientras el operador todavía esté en estado:

```text
Loading
```

Si `/operators/me` falla, la aplicación debe mostrar un estado de error apropiado.

No se debe asumir que el usuario es operador simplemente porque el JWT sea válido.

---

# 9. Restauración de sesión

Al iniciar la aplicación:

```text
Restore Session
      ↓
Session valid?
      │
      ├── No → Authentication flow
      │
      └── Yes
           ↓
      Bootstrap Operator
           ↓
      GET /operators/me
```

El operador puede mantenerse únicamente como estado de aplicación si el backend debe ser consultado nuevamente al restaurar sesión.

No convertir el almacenamiento local del operador en autoridad.

La fuente de verdad continúa siendo:

```text
NexoVending → /operators/me
```

---

# 10. Persistencia del operador

Si se decide persistir datos del operador para mejorar la experiencia de arranque:

* almacenar únicamente datos no sensibles;
* nunca almacenar JWT dentro de este mecanismo;
* no almacenar permisos como fuente de autoridad;
* no almacenar información que permita modificar la identidad del operador;
* invalidar el contexto local al hacer logout.

El JWT continúa exclusivamente en `SecureStorage` según Commit 4.

La persistencia local del operador debe considerarse una **caché**, no una autoridad.

---

# 11. Manejo de errores

Mapear las respuestas del backend mediante las excepciones existentes del Commit 2.

Casos mínimos:

### `401 Unauthorized`

Significa que la sesión ya no es válida.

Flujo:

```text
/operators/me → 401
        ↓
Session expired
        ↓
Clear session
        ↓
Authentication flow
```

No intentar renovar automáticamente en este commit si el mecanismo de refresh no forma parte del contrato actual.

### `403 Forbidden`

La identidad autenticada no tiene acceso permitido al recurso.

La aplicación debe mostrar un estado de acceso denegado.

No transformar `403` en:

```text
operator = null
```

ni crear un operador local.

### `404 Not Found`

Si el contrato utiliza `404` para indicar que no existe un operador asociado:

```text
Authenticated identity
        ↓
No Vending operator
```

debe mostrarse como un estado de bootstrap fallido/no configurado.

No crear automáticamente un operador.

### `5xx`

Mostrar error transitorio y permitir reintentar.

### Network / Timeout

Utilizar las excepciones de infraestructura existentes.

No duplicar lógica HTTP dentro de `OperatorService`.

---

# 12. UI

Crear una UI mínima para los estados:

### Loading

```text
Cargando operador...
```

### Success

Permitir entrar al shell principal de la aplicación.

En este commit no es necesario implementar todavía la pantalla completa de operaciones.

Puede utilizarse un placeholder:

```text
Bienvenido, <operator>
```

### No autorizado

Mostrar:

```text
No tienes acceso a la aplicación de operaciones.
```

### No configurado

Mostrar:

```text
Tu usuario todavía no está configurado como operador.
```

### Error de red

Mostrar:

```text
No fue posible cargar tu información.
```

con acción:

```text
Reintentar
```

Los textos pueden ajustarse posteriormente con internacionalización.

---

# 13. Arquitectura

La dependencia debe mantener la dirección:

```text
UI
 ↓
Application
 ↓
OperatorService
 ↓
ApiClient
 ↓
HTTP
```

No permitir:

```text
Widget
 ↓
http package
```

ni:

```text
Widget
 ↓
SecureStorage
```

La UI debe interactuar con el estado de aplicación y casos de uso.

---

# 14. Estructura propuesta

```text
lib/
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── ...
│
├── core/
│   ├── config/
│   ├── networking/
│   ├── storage/
│   ├── logging/
│   └── ...
│
├── features/
│   └── operator/
│       ├── data/
│       │   ├── models/
│       │   │   └── operator_model.dart
│       │   └── services/
│       │       └── api_operator_service.dart
│       │
│       ├── domain/
│       │   ├── entities/
│       │   │   └── operator.dart
│       │   └── operator_service.dart
│       │
│       └── presentation/
│           ├── operator_bootstrap_controller.dart
│           ├── operator_bootstrap_page.dart
│           └── operator_state.dart
│
└── main.dart
```

La estructura puede adaptarse a la arquitectura establecida en Commits 1–4, pero debe mantenerse la separación:

```text
domain
application/presentation
data/infrastructure
```

---

# 15. Dependency Injection

Registrar:

```text
OperatorService
ApiOperatorService
OperatorBootstrapController
```

El `ApiClient` debe ser la instancia autenticada proveniente de la infraestructura existente.

No crear un segundo cliente HTTP específico para operadores.

---

# 16. Tests unitarios

Crear tests para `OperatorService`.

### Caso 1 — operador encontrado

Mock/fake:

```http
200 OK
```

Debe:

* realizar `GET /api/v1/operators/me`;
* enviar mediante ApiClient autenticado;
* mapear correctamente el JSON;
* devolver `Operator`.

### Caso 2 — respuesta inválida

Debe producir:

```text
SerializationException
```

o la excepción de dominio/infrastructure definida para payload inválido.

### Caso 3 — 401

Debe propagar el error de autenticación correspondiente.

### Caso 4 — 403

Debe representar correctamente acceso denegado.

### Caso 5 — 404

Debe representar operador no configurado según el contrato.

### Caso 6 — 500

Debe propagar `HttpException`/error equivalente.

### Caso 7 — timeout

Debe producir `TimeoutException`.

### Caso 8 — network failure

Debe producir `NetworkException`.

---

# 17. Tests de bootstrap

Probar la máquina de estados:

```text
Initial
  ↓
Loading
  ↓
Loaded
```

También:

```text
Loading
  ↓
Failure
```

y:

```text
Loading
  ↓
Unauthorized
```

Verificar que:

* no se muestre la aplicación funcional mientras carga;
* un operador válido permita continuar;
* un error permita reintentar;
* un `401` invalide la sesión;
* un `403` no cree un operador;
* un operador inexistente no genere un usuario ficticio.

---

# 18. Tests de integración HTTP

Implementar tests contra un servidor HTTP fake/in-memory.

Verificar la solicitud real:

```http
GET /api/v1/operators/me
Authorization: Bearer <jwt>
```

Debe comprobarse explícitamente que:

* el método sea `GET`;
* la ruta sea correcta;
* el header `Authorization` exista;
* el token corresponda al Session JWT;
* no se envíen credenciales Google en esta llamada;
* el JSON se transforme correctamente.

Ejemplo conceptual:

```text
POST /auth/session
        ↓
JWT
        ↓
GET /operators/me
        ↓
Operator
```

El objetivo es verificar la integración entre Commit 4 y Commit 5.

---

# 19. Tests de seguridad

Agregar tests que garanticen:

* JWT no aparece en logs;
* `id_token` de Google no se envía a `/operators/me`;
* JWT no se persiste en almacenamiento normal;
* operator cache no contiene tokens;
* logout elimina el contexto local del operador;
* errores no imprimen Authorization headers.

---

# 20. Tests widget

Cubrir como mínimo:

### Authenticated + operator loaded

Debe mostrar:

```text
Bienvenido...
```

o el shell equivalente.

### Loading

Debe mostrar indicador de carga.

### Failure

Debe mostrar error y botón:

```text
Reintentar
```

### 403

Debe mostrar acceso denegado.

### 401

Debe devolver al flujo de autenticación.

### Logout

Debe eliminar:

```text
Session
Operator context
```

---

# 21. Criterios de aceptación

El commit se considera aceptado cuando:

## 21.1 Operator API

* [ ] `GET /api/v1/operators/me` está implementado.
* [ ] Utiliza exclusivamente el `ApiClient` existente.
* [ ] Utiliza automáticamente el Session JWT.
* [ ] No requiere que cada feature construya el header Authorization.

## 21.2 Operator model

* [ ] Existe un modelo `Operator`.
* [ ] Los campos corresponden al contrato real de NexoVending.
* [ ] El modelo no contiene lógica de infraestructura.
* [ ] No se inventan datos de operador.

## 21.3 Bootstrap

* [ ] Una sesión válida dispara el bootstrap del operador.
* [ ] Un operador válido permite continuar a la aplicación.
* [ ] El estado de carga está representado.
* [ ] Los errores están representados.
* [ ] Existe posibilidad de reintento.

## 21.4 Authentication boundary

* [ ] Session y Operator permanecen conceptualmente separados.
* [ ] JWT continúa siendo autoridad de autenticación.
* [ ] `/operators/me` continúa siendo autoridad sobre el operador Vending.
* [ ] Flutter no fabrica operadores.

## 21.5 Error handling

* [ ] `401` invalida la sesión.
* [ ] `403` se trata como acceso denegado.
* [ ] `404`, si corresponde al contrato, se trata como operador no configurado.
* [ ] `5xx` permite recuperación/reintento.
* [ ] Network/timeout utilizan la infraestructura existente.

## 21.6 Security

* [ ] JWT no aparece en logs.
* [ ] Google `id_token` no se reutiliza para llamadas de negocio.
* [ ] No existe almacenamiento inseguro del JWT.
* [ ] El operador cacheado nunca se considera autoridad.

## 21.7 Tests

* [ ] Tests unitarios de `OperatorService`.
* [ ] Tests de estados del bootstrap.
* [ ] Tests de errores.
* [ ] Tests de integración HTTP.
* [ ] Tests widget.
* [ ] Tests de seguridad.
* [ ] Toda la suite existente continúa pasando.
* [ ] `dart format` pasa.
* [ ] `flutter analyze` pasa.
* [ ] `flutter test` pasa.

---

# 22. Documentación

Actualizar:

```text
README.md
ARCHITECTURE.md
AUTHENTICATION.md
SESSION.md
```

Crear:

```text
docs/OPERATOR_BOOTSTRAP.md
```

Y un ADR:

```text
docs/adr/ADR-004-operator-bootstrap.md
```

---

# 23. `OPERATOR_BOOTSTRAP.md`

Debe documentar:

* propósito;
* endpoint utilizado;
* relación Session → Operator;
* modelo de datos;
* flujo de bootstrap;
* estados;
* manejo de errores;
* restauración;
* logout;
* seguridad;
* estrategia de caché;
* testing.

Incluir explícitamente:

```text
The mobile application does not determine who the Vending operator is.
NexoVending is the authority for the Vending operator identity.
```

---

# 24. ADR-004

Título:

```text
ADR-004 — Vending Operator Bootstrap
```

Decisión:

```text
After establishing an authenticated NexoVending session,
VendingApp resolves the current Vending operator through
GET /api/v1/operators/me.
```

Justificación:

* separar autenticación de identidad de negocio;
* mantener NexoVending como autoridad;
* evitar duplicar operadores en Flutter;
* permitir que futuras reglas de autorización permanezcan en backend.

Consecuencias:

```text
Session != Operator
```

y:

```text
Valid JWT != Valid Vending Operator
```

---

# 25. Actualización de ARCHITECTURE.md

Agregar:

```text
Google Identity
      ↓
NexoVending Session
      ↓
Vending Operator
      ↓
Vending Features
```

La aplicación móvil continúa siendo cliente de:

```text
NexoVending Public HTTP API
```

No debe aparecer ninguna dependencia de:

```text
nexo_platform
```

ni de sus APIs internas.

---

# 26. Definition of Done

El Commit 5 está terminado únicamente cuando:

## 26.1 Código

* [ ] `Operator` implementado.
* [ ] `OperatorService` implementado.
* [ ] `ApiOperatorService` implementado.
* [ ] Bootstrap controller/state implementado.
* [ ] UI mínima implementada.
* [ ] Dependency injection actualizada.
* [ ] No hay duplicación del cliente HTTP.
* [ ] No hay lógica de negocio de Vending en Flutter.

## 26.2 Integración

* [ ] Session del Commit 4 se reutiliza.
* [ ] `GET /api/v1/operators/me` funciona.
* [ ] Authorization Bearer se agrega centralizadamente.
* [ ] `401` conecta correctamente con la expiración de sesión.

## 26.3 Tests

* [ ] Unit tests completos.
* [ ] HTTP integration tests completos.
* [ ] Widget tests completos.
* [ ] Security tests completos.
* [ ] Suite anterior sin regresiones.

## 26.4 Calidad

* [ ] `dart format` sin cambios pendientes.
* [ ] `flutter analyze` sin errores.
* [ ] `flutter test` completamente verde.
* [ ] Sin warnings críticos.
* [ ] Sin secretos en código.
* [ ] Sin tokens en logs.

## 26.5 Documentación

* [ ] `README.md` actualizado.
* [ ] `ARCHITECTURE.md` actualizado.
* [ ] `AUTHENTICATION.md` actualizado.
* [ ] `SESSION.md` actualizado.
* [ ] `OPERATOR_BOOTSTRAP.md` creado.
* [ ] `ADR-004` creado.

## 26.6 Boundary

* [ ] VendingApp consume exclusivamente la API pública HTTP de NexoVending.
* [ ] No importa Platform directamente.
* [ ] No replica lógica de NexoVending.
* [ ] No determina permisos de negocio.
* [ ] No fabrica identidad de operador.
* [ ] No mantiene un ledger local.

---

# 27. Resultado esperado

Al finalizar este commit, VendingApp debe haber alcanzado:

```text
Google identity
      ↓
NexoVending session
      ↓
Authenticated JWT
      ↓
Current Vending Operator
      ↓
Application shell
```

La aplicación todavía **no realiza operaciones de vending**.

El siguiente paso natural es:

```text
Commit 6
feat(mobile): implement machine identification
```

que utilizará el contexto de operador ya establecido para comenzar el flujo operacional de terreno.
