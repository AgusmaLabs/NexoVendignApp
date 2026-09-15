# Commit 9 — Barcode Product Lookup

## Commit

```text
feat(mobile): implement barcode product lookup
```

## 1. Objetivo

Implementar en **VendingApp** la capacidad de escanear o ingresar un código de barras y consultar el producto correspondiente mediante la API pública de **NexoVending**.

El flujo introducido será:

```text
Authenticated Session
        ↓
Current Replenishment
        ↓
Barcode Scanner / Manual Barcode
        ↓
NexoVending Product Lookup
        ↓
Product Found / Product Not Found / Error
```

Este commit permite conocer qué producto corresponde a un código de barras, pero **no agrega todavía el producto a la reposición**.

La responsabilidad de determinar qué producto existe, su descripción y sus datos comerciales permanece en NexoVending.

---

# 2. Alcance

## Incluye

* Abstracción de lectura de códigos de barras.
* Implementación inicial del scanner para Android/iOS.
* Entrada manual de código de barras como fallback.
* Modelo `Product`.
* Contrato `ProductLookupService`.
* Implementación HTTP `ApiProductLookupService`.
* Consulta autenticada a NexoVending.
* Estados de lookup.
* Manejo de producto encontrado.
* Manejo de código de barras no encontrado.
* Manejo de errores de red/API.
* UI mínima para:

  * iniciar escaneo;
  * mostrar código detectado;
  * consultar producto;
  * mostrar producto encontrado;
  * permitir reintentar cuando no existe.
* Integración con:

  * `Session`;
  * `ApiClient`;
  * `Current Replenishment`.
* Tests unitarios, HTTP, widget e integración.

## No incluye

Este commit **NO** implementa:

* agregar producto a una línea de reposición;
* ingresar cantidad;
* seleccionar slot;
* modificar inventario;
* modificar stock;
* completar reposición;
* sustituciones;
* creación de productos;
* edición de productos;
* resolución manual persistente de productos desconocidos;
* historial;
* funcionamiento offline;
* sincronización offline.

---

# 3. Principio arquitectónico

VendingApp es un consumidor de la API pública de NexoVending.

```text
VendingApp
    │
    │ HTTP + Session JWT
    ▼
NexoVending
    │
    ├── autenticación
    ├── autorización
    ├── tenant
    ├── catálogo
    └── producto
```

La aplicación móvil **no posee autoridad sobre el catálogo**.

No debe:

* crear productos localmente;
* inferir productos por nombre;
* mantener un catálogo paralelo;
* decidir si un barcode pertenece a un producto;
* modificar información comercial.

El backend es la fuente de verdad.

---

# 4. Flujo funcional

## 4.1 Inicio

El usuario se encuentra dentro de una reposición activa:

```text
Current Operator
       +
Current Machine
       +
Current Replenishment
```

Desde la pantalla de reposición selecciona:

```text
Escanear producto
```

---

## 4.2 Escaneo

El scanner obtiene un valor:

```text
barcode = "7801234567890"
```

El valor debe validarse antes de enviarlo al backend.

Como mínimo:

* no vacío;
* longitud razonable;
* caracteres permitidos por el contrato;
* eliminar espacios accidentales.

La validación móvil es solamente de formato.

La validez comercial del código pertenece al backend.

---

## 4.3 Lookup

La aplicación ejecuta la operación equivalente a:

```http
GET /api/v1/products/barcode/{barcode}
Authorization: Bearer <session-jwt>
X-Request-Id: <request-id>
```

> El path exacto debe ajustarse al contrato HTTP vigente de NexoVending si éste difiere. VendingApp no debe inventar un endpoint distinto al contrato público.

---

# 5. Modelo Product

Crear:

```text
lib/features/products/domain/product.dart
```

El modelo debe representar únicamente la información expuesta por el contrato móvil.

Ejemplo conceptual:

```dart
class Product {
  final String id;
  final String barcode;
  final String description;
}
```

Si el contrato actual expone otros campos, éstos pueden incorporarse únicamente cuando sean necesarios para el flujo móvil.

No incorporar información interna de NexoVending que no forme parte del contrato público.

## Invariantes

`Product` debe cumplir:

* `id` no vacío;
* `barcode` no vacío;
* `description` no vacía cuando el contrato la garantiza;
* igualdad basada en identidad estable del producto.

---

# 6. ProductLookupService

Crear el contrato:

```text
lib/features/products/domain/product_lookup_service.dart
```

Conceptualmente:

```dart
abstract interface class ProductLookupService {
  Future<Product> lookupByBarcode(String barcode);
}
```

El dominio móvil conoce la capacidad:

```text
lookupByBarcode()
```

pero no conoce:

* HTTP;
* headers;
* JWT;
* Dio/http;
* rutas concretas;
* JSON.

---

# 7. ApiProductLookupService

Crear:

```text
lib/features/products/infrastructure/api_product_lookup_service.dart
```

Responsabilidades:

1. recibir barcode;
2. validar formato básico;
3. construir request;
4. utilizar `ApiClient`;
5. enviar JWT automáticamente mediante la infraestructura existente;
6. convertir respuesta HTTP en `Product`;
7. convertir errores HTTP en errores de aplicación.

No debe acceder directamente a `SecureStorage`.

El JWT continúa siendo responsabilidad de la infraestructura de sesión creada en Commit 4.

---

# 8. Estados de Product Lookup

Crear un estado explícito.

Por ejemplo:

```text
Idle
Scanning
LookingUp
Found
NotFound
Failure
```

## Idle

No existe ninguna búsqueda activa.

---

## Scanning

El scanner está abierto.

---

## LookingUp

Existe un barcode y se está consultando NexoVending.

Durante este estado:

* evitar múltiples requests simultáneos;
* deshabilitar acciones duplicadas;
* mostrar progreso.

---

## Found

El backend devolvió un producto válido.

Debe conservar:

```text
barcode
product
```

---

## NotFound

El backend respondió que el barcode no corresponde a ningún producto.

Esto **no significa que el producto sea inválido para siempre**.

Significa solamente:

```text
No existe una coincidencia conocida en el catálogo
```

La UI debe permitir:

```text
Reintentar
Ingresar código manualmente
```

El flujo de descripción manual se implementará posteriormente.

---

## Failure

Error distinto de "producto no encontrado".

Debe conservar información suficiente para presentar una acción adecuada.

---

# 9. Manejo de errores

Mapear como mínimo:

| Backend         | Estado móvil             |
| --------------- | ------------------------ |
| 200             | `Found`                  |
| 404             | `NotFound`               |
| 401             | sesión inválida/expirada |
| 403             | acceso denegado          |
| 422             | barcode inválido         |
| 429             | rate limit               |
| 5xx             | error temporal           |
| timeout         | error de red             |
| network failure | error de red             |

## 401

No crear una sesión nueva silenciosamente.

Delegar al mecanismo de sesión existente.

El flujo debe terminar en:

```text
Session expired
    ↓
Unauthenticated
```

según la infraestructura implementada en Commit 4.

---

# 10. Barcode Scanner

Crear una abstracción:

```text
lib/core/barcode/barcode_scanner.dart
```

Por ejemplo:

```dart
abstract interface class BarcodeScanner {
  Future<String?> scan();
}
```

La aplicación no debe depender directamente del SDK de cámara desde las capas de dominio.

Arquitectura:

```text
UI
 ↓
BarcodeScanner
 ↓
Scanner Adapter
 ↓
Camera / Barcode SDK
```

---

# 11. Scanner Adapter

Agregar la implementación concreta bajo infraestructura:

```text
lib/core/barcode/
    barcode_scanner.dart
    barcode_scanner_impl.dart
```

El SDK concreto puede ser reemplazado posteriormente sin modificar:

* Product;
* ProductLookupService;
* Replenishment;
* Application state.

---

# 12. Manual Barcode Input

El scanner no debe ser el único mecanismo.

Agregar una alternativa:

```text
Ingresar código manualmente
```

Esto es importante para escenarios de terreno donde:

* el código está deteriorado;
* existe poca iluminación;
* la cámara no consigue enfocar;
* el usuario necesita repetir una consulta.

El valor ingresado manualmente debe recorrer exactamente el mismo:

```text
ProductLookupService.lookupByBarcode()
```

No debe existir un segundo flujo de consulta.

---

# 13. UI

Agregar una pantalla/componente de lookup asociado a la reposición.

Conceptualmente:

```text
┌─────────────────────────────┐
│ Agregar producto            │
│                             │
│       [ Escanear ]          │
│                             │
│       o                     │
│                             │
│ Código de barras            │
│ [ 7801234567890 ]           │
│                             │
│       [ Buscar ]            │
└─────────────────────────────┘
```

Producto encontrado:

```text
┌─────────────────────────────┐
│ Producto encontrado         │
│                             │
│ Coca Cola 350 ml            │
│ Código: 7801234567890       │
│                             │
│       [ Continuar ]         │
└─────────────────────────────┘
```

El botón `Continuar` todavía **no agrega una línea**.

Puede entregar el `Product` al siguiente estado de aplicación que será implementado en Commit 10.

---

# 14. Integración con Current Replenishment

El lookup ocurre dentro del contexto de una reposición activa.

Debe existir:

```text
CurrentReplenishmentContext
```

antes de acceder al flujo de productos.

Sin reposición activa:

```text
No se permite iniciar el flujo de producto
```

La aplicación no debe intentar crear una reposición automáticamente desde este commit.

---

# 15. Separación entre Product Lookup y Replenishment Line

Esta separación es obligatoria.

```text
Barcode
   ↓
Product Lookup
   ↓
Product
```

y posteriormente:

```text
Product
   +
Quantity
   +
Slot
   ↓
Replenishment Line
```

Por lo tanto, Commit 9 **no debe introducir**:

```dart
AddReplenishmentLine(...)
```

ni lógica equivalente.

Esto mantiene los commits pequeños y evita mezclar:

* catálogo;
* captura de producto;
* cantidad;
* slot;
* inventario.

---

# 16. Producto no encontrado

Cuando:

```text
barcode → 404
```

la aplicación debe mostrar:

```text
Producto no encontrado
```

y ofrecer:

```text
[ Escanear nuevamente ]
[ Ingresar código ]
```

No debe:

* crear el producto;
* asumir que es un producto nuevo;
* inventar un `product_id`;
* insertar información en la base local como si fuera un producto;
* modificar inventario.

La resolución de productos desconocidos queda para el commit específico de workflow de producto no resuelto.

---

# 17. Tests

## 17.1 Tests unitarios

Crear:

```text
test/features/products/domain/
```

### Product

Probar:

* construcción válida;
* rechazo de datos inválidos;
* igualdad;
* serialización/deserialización si corresponde.

### Barcode validation

Probar:

* barcode válido;
* vacío;
* espacios;
* formato inválido;
* normalización esperada.

### ProductLookupService

Probar mediante fake:

```text
barcode → Product
```

y:

```text
barcode → NotFound
```

---

# 18. Tests de ApiProductLookupService

Crear:

```text
test/features/products/infrastructure/
```

Probar:

### Producto encontrado

```text
HTTP 200
    ↓
Product
```

Validar:

* id;
* barcode;
* description.

### Producto no encontrado

```text
HTTP 404
    ↓
ProductNotFound
```

### Unauthorized

```text
HTTP 401
    ↓
SessionExpired / Unauthorized
```

### Forbidden

```text
HTTP 403
    ↓
AccessDenied
```

### Validation

```text
HTTP 422
    ↓
InvalidBarcode
```

### Server failure

```text
HTTP 500
    ↓
ServerError
```

### Timeout

Debe convertirse en el error de red correspondiente.

---

# 19. Tests de autenticación

Verificar que el lookup utilice:

```http
Authorization: Bearer <session-jwt>
```

y que la aplicación:

* no envíe `id_token` de Google;
* no envíe credenciales Google al endpoint de productos;
* no almacene el JWT fuera del mecanismo SecureStorage;
* no permita ejecutar el lookup autenticado sin sesión.

---

# 20. Tests de request context

Verificar que el request incluya el mecanismo existente de:

```text
X-Request-Id
```

cuando corresponda según `ApiClient`.

No generar una implementación paralela de request IDs.

---

# 21. Tests del scanner

Crear fake:

```dart
FakeBarcodeScanner
```

Casos:

### Scan success

```text
scanner → "7801234567890"
```

debe iniciar lookup.

### Scan cancelled

```text
scanner → null
```

no debe realizar request.

### Repeated scan

No debe generar múltiples requests concurrentes para la misma operación.

---

# 22. Tests de UI

Crear:

```text
test/features/products/presentation/
```

Probar:

### Estado inicial

Muestra:

```text
Escanear
Ingresar código
```

### Scanner

Al detectar barcode:

```text
Scanning
    ↓
LookingUp
```

### Producto encontrado

Debe mostrar:

* descripción;
* barcode;
* acción continuar.

### Producto no encontrado

Debe mostrar:

```text
Producto no encontrado
```

y permitir:

```text
Reintentar
```

### Error de red

Debe mostrar mensaje recuperable y permitir retry.

### Sesión expirada

Debe delegar al flujo de autenticación existente.

---

# 23. Test de aislamiento de reposición

Verificar que:

```text
Replenishment A
    ↓
Product Lookup
```

no pueda modificar ni contaminar:

```text
Replenishment B
```

El lookup debe ser una consulta de catálogo.

No debe existir mutación de reposición.

---

# 24. Test de no mutación de inventario

Debe existir una prueba que garantice que:

```text
barcode lookup
```

no produce:

* stock movement;
* inventory movement;
* replenishment line;
* quantity change;
* slot assignment.

Este test protege una frontera arquitectónica importante.

---

# 25. Test HTTP de integración

Usar el mecanismo de fake HTTP/server utilizado por la aplicación.

Casos mínimos:

```text
GET product by barcode
```

con:

* JWT;
* request ID;
* respuesta 200;
* respuesta 404;
* respuesta 401;
* respuesta 403;
* respuesta 422;
* respuesta 500.

No es necesario utilizar PostgreSQL desde Flutter para este commit.

La persistencia pertenece al backend NexoVending.

---

# 26. Test de flujo completo

Agregar un test de integración móvil:

```text
Authenticated Session
      ↓
Current Replenishment
      ↓
Scan Barcode
      ↓
HTTP Lookup
      ↓
Product Found
```

Debe terminar con un `Product` disponible para el siguiente paso del flujo.

No debe crear todavía una línea.

---

# 27. Criterios de aceptación

## AC-01 — Lookup autenticado

Dado un usuario autenticado y una reposición activa,

cuando escanea un barcode válido,

entonces VendingApp consulta NexoVending usando el Session JWT.

---

## AC-02 — Producto encontrado

Dado un barcode registrado,

cuando el backend responde `200`,

entonces la aplicación muestra el producto correspondiente.

---

## AC-03 — Producto inexistente

Dado un barcode no registrado,

cuando el backend responde `404`,

entonces la aplicación muestra `Producto no encontrado`.

---

## AC-04 — Reintento

Desde `Product Not Found` el usuario puede volver a:

```text
Escanear
```

o:

```text
Ingresar código
```

sin abandonar la reposición.

---

## AC-05 — Entrada manual

Un barcode ingresado manualmente debe utilizar exactamente el mismo servicio que un barcode obtenido mediante cámara.

---

## AC-06 — Sesión

Toda consulta de producto debe utilizar:

```http
Authorization: Bearer <session-jwt>
```

Nunca debe utilizar directamente el `id_token` de Google.

---

## AC-07 — Sin tenant arbitrario

VendingApp no debe permitir seleccionar ni enviar un `tenant_id` arbitrario durante el lookup.

El contexto de tenant pertenece a la sesión/backend.

---

## AC-08 — Sin mutación

El lookup no puede:

* crear líneas;
* cambiar cantidades;
* asignar slots;
* modificar inventario;
* modificar stock.

---

## AC-09 — Sin catálogo local paralelo

VendingApp no debe persistir un catálogo de productos como fuente de verdad.

---

## AC-10 — Backend authority

La aplicación debe utilizar la información devuelta por NexoVending como fuente de verdad del producto.

---

## AC-11 — Error handling

Los errores `401`, `403`, `404`, `422`, `5xx` y errores de red deben tener estados diferenciados y acciones coherentes.

---

## AC-12 — Cancelación

Si el usuario cancela el scanner, no debe ejecutarse ningún lookup.

---

## AC-13 — No concurrencia accidental

Múltiples taps o eventos de scanner no deben producir múltiples requests simultáneos para la misma operación.

---

## AC-14 — Preparado para Commit 10

El resultado de un lookup exitoso debe poder entregarse al siguiente flujo:

```text
Product
    ↓
Replenishment Line
```

sin rediseñar `Product` ni `ProductLookupService`.

---

# 28. Documentación

Crear:

```text
docs/PRODUCT_LOOKUP.md
```

Debe documentar:

* propósito;
* flujo;
* contrato utilizado;
* modelo `Product`;
* estados;
* errores;
* scanner;
* entrada manual;
* seguridad;
* límites del commit.

---

# 29. Actualizar ARCHITECTURE.md

Agregar:

```text
Product Lookup
```

dentro de la arquitectura de features:

```text
Presentation
    ↓
Application
    ↓
Domain
    ↓
Infrastructure
    ↓
NexoVending API
```

Dejar explícito:

```text
Product catalog authority = NexoVending
```

---

# 30. Actualizar ADR

Crear:

```text
docs/adr/ADR-006-product-catalog-authority.md
```

> Si el repositorio ya utiliza `ADR-006` para Machine Detail/Slots, mantener la numeración existente y asignar el siguiente número disponible.

## Decisión

El catálogo de productos pertenece a NexoVending.

VendingApp solamente:

* consulta;
* presenta;
* transporta la referencia del producto al siguiente flujo.

No posee autoridad para:

* crear;
* modificar;
* eliminar;
* resolver comercialmente productos.

## Consecuencia

La aplicación depende del contrato HTTP público de NexoVending para conocer productos.

Esto permite que el catálogo evolucione en backend sin duplicar la lógica en Flutter.

---

# 31. Actualizar AUTHENTICATION.md

Documentar que el lookup de productos:

```text
Google id_token
```

NO se utiliza directamente.

El flujo correcto es:

```text
Google
  ↓
Session JWT
  ↓
ApiClient
  ↓
Product Lookup
```

---

# 32. Actualizar REPLENISHMENT.md

Agregar la relación:

```text
Current Replenishment
        ↓
Product Lookup
```

pero dejar explícitamente que:

```text
Product Lookup ≠ Add Line
```

La creación de líneas será responsabilidad del siguiente commit.

---

# 33. Actualizar README

Incluir en el estado del producto:

```text
Commit 9 — Barcode Product Lookup
```

y marcar:

```text
Authentication             ✓
Session                    ✓
Operator Bootstrap         ✓
Machine Identification     ✓
Machine Detail / Slots     ✓
Replenishment Creation     ✓
Barcode Product Lookup     ✓
Replenishment Lines        pending
```

---

# 34. Definition of Done

El Commit 9 solamente se considera terminado cuando:

1. Existe `Product` como modelo móvil.
2. Existe `ProductLookupService`.
3. Existe `ApiProductLookupService`.
4. El lookup utiliza el `ApiClient` existente.
5. El JWT se transmite mediante `Authorization: Bearer`.
6. Google `id_token` no se utiliza para llamadas de negocio.
7. Existe abstracción `BarcodeScanner`.
8. Existe implementación concreta del scanner.
9. Existe entrada manual de barcode.
10. Scanner y entrada manual utilizan el mismo lookup.
11. `200` produce un `Product`.
12. `404` produce `NotFound`.
13. `401` respeta el flujo de expiración de sesión.
14. `403` produce acceso denegado.
15. `422` produce barcode inválido.
16. `5xx` produce error recuperable.
17. Los errores de red son recuperables.
18. Cancelar scanner no realiza requests.
19. Se evita concurrencia accidental de requests.
20. Existe integración con `CurrentReplenishment`.
21. El lookup no crea líneas.
22. El lookup no modifica cantidades.
23. El lookup no asigna slots.
24. El lookup no modifica inventario.
25. No existe catálogo local como fuente de verdad.
26. Existen tests unitarios.
27. Existen tests de infraestructura HTTP.
28. Existen tests de estados.
29. Existen tests de scanner.
30. Existen tests de widgets.
31. Existe test de flujo integrado.
32. Existe test explícito de no mutación.
33. La documentación de producto está actualizada.
34. `ARCHITECTURE.md` está actualizado.
35. El ADR correspondiente está documentado.
36. `AUTHENTICATION.md` está actualizado.
37. `REPLENISHMENT.md` está actualizado.
38. README refleja el nuevo estado.
39. `flutter analyze` pasa sin errores.
40. `flutter test` pasa completamente.
41. No existen dependencias directas desde dominio hacia SDK HTTP/cámara.
42. No se introducen cambios fuera del alcance del commit.

---

# 35. Resultado esperado

Al finalizar este commit, el flujo móvil queda:

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
```

Y queda preparado para el siguiente commit:

```text
Commit 10
Replenishment Lines
```

que podrá consumir:

```text
Product
   +
Quantity
   +
Slot
   ↓
Replenishment Line
```

sin que Commit 9 tenga que conocer las reglas de cantidad, slot, stock o inventario.
