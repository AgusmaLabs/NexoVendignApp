# Commit 2 — Application Infrastructure

## Commit

```text
feat(mobile): introduce application infrastructure
```

## Objetivo

Introducir la infraestructura transversal de VendingApp necesaria para que las futuras funcionalidades puedan comunicarse con la API pública de NexoVending de forma consistente, observable y testeable.

Este commit establece:

* cliente HTTP;
* configuración de networking;
* manejo centralizado de errores;
* request IDs;
* logging;
* abstracción de almacenamiento local;
* abstracciones básicas de dispositivo;
* inyección de dependencias;
* base para futuras implementaciones de autenticación y operaciones.

**No implementa todavía autenticación, Google Sign-In, JWT ni ninguna funcionalidad de vending.**

---

# 1. Alcance

## Incluye

* HTTP client abstraction.
* HTTP request/response models.
* API base URL desde `AppConfig`.
* Headers comunes.
* `X-Request-Id`.
* Timeout configurable.
* Manejo centralizado de errores HTTP y de conectividad.
* Logging abstraction.
* Local storage abstraction.
* Secure storage abstraction/interface preparada para Commit 3/4.
* Connectivity abstraction.
* Location abstraction preparada para futuros commits.
* Barcode scanner abstraction preparada para futuros commits.
* Dependency injection/composition root.
* Tests unitarios.
* Tests de integración del cliente HTTP con servidor mock.
* Actualización de arquitectura y documentación.
* CI ampliado.

## No incluye

* Google Sign-In.
* OAuth.
* Session JWT.
* `/auth/session`.
* `/operators/me`.
* Login UI.
* QR.
* Barcode scanner implementation.
* GPS implementation.
* Machine API.
* Product API.
* Replenishment API.
* Inventory.
* Offline synchronization.

---

# 2. Estructura

Ampliar la estructura creada en Commit 1:

```text
lib/
├── app/
│   ├── app.dart
│   ├── router/
│   │   └── app_router.dart
│   └── theme/
│       └── app_theme.dart
│
├── core/
│   ├── config/
│   │   └── app_config.dart
│   │
│   ├── networking/
│   │   ├── api_client.dart
│   │   ├── api_request.dart
│   │   ├── api_response.dart
│   │   ├── api_exception.dart
│   │   └── request_id.dart
│   │
│   ├── errors/
│   │   └── app_exception.dart
│   │
│   ├── logging/
│   │   └── app_logger.dart
│   │
│   ├── storage/
│   │   ├── local_storage.dart
│   │   └── secure_storage.dart
│   │
│   └── device/
│       ├── connectivity_service.dart
│       ├── location_service.dart
│       └── barcode_scanner.dart
│
└── main.dart
```

Las implementaciones concretas de servicios de dispositivo pueden quedar para commits posteriores.

---

# 3. Networking

Crear una abstracción central:

```text
ApiClient
```

Su responsabilidad es encapsular la comunicación HTTP con NexoVending.

Debe permitir como mínimo:

```text
GET
POST
PUT
PATCH
DELETE
```

aunque no necesariamente todas serán utilizadas en este commit.

El cliente debe recibir:

```text
AppConfig
Logger
RequestIdGenerator
```

mediante composición/inyección.

No debe existir código HTTP directamente dentro de widgets.

---

# 4. API Base URL

El cliente debe utilizar:

```text
AppConfig.apiBaseUrl
```

como origen de las llamadas.

No se permite:

```text
hardcoded URL
```

dentro de:

* widgets;
* features;
* repositories;
* servicios específicos.

La URL pertenece a configuración de aplicación.

---

# 5. Request ID

Implementar generación de un identificador único por request.

Cada request HTTP debe incluir:

```http
X-Request-Id: <uuid>
```

El identificador debe:

* ser generado automáticamente cuando no exista;
* ser suficientemente único;
* estar disponible para logging;
* permitir correlacionar errores de cliente con backend.

El mecanismo debe quedar preparado para que posteriormente una capa superior pueda proporcionar explícitamente un request ID.

---

# 6. Headers

El `ApiClient` debe permitir headers comunes.

En este commit se establece solamente la infraestructura.

No implementar todavía:

```http
Authorization: Bearer ...
```

porque la autenticación será introducida posteriormente.

Tampoco introducir:

```http
X-Tenant-Id
```

como lógica de negocio.

Los headers de autenticación y tenant serán responsabilidad de los commits correspondientes a sesión y contexto.

---

# 7. Timeout

Configurar timeout para las operaciones HTTP.

Debe ser:

* configurable;
* aplicado consistentemente;
* transformado en un error de aplicación identificable.

No permitir requests que queden indefinidamente pendientes.

El valor exacto puede ser definido mediante `AppConfig`.

---

# 8. API Exceptions

Crear una jerarquía de errores de infraestructura.

Como mínimo distinguir:

```text
NetworkException
TimeoutException
HttpException
SerializationException
UnknownApiException
```

Los errores no deben propagarse como excepciones específicas del paquete HTTP utilizado.

La aplicación debe depender de sus propias abstracciones.

Esto permite cambiar posteriormente el cliente HTTP sin modificar las features.

---

# 9. HTTP Error Mapping

El `ApiClient` debe transformar códigos HTTP en errores internos.

Como mínimo:

```text
400 → HttpException
401 → HttpException
403 → HttpException
404 → HttpException
409 → HttpException
422 → HttpException
429 → HttpException
500+ → HttpException
```

No implementar todavía interpretación de errores específicos de vending como:

```text
MACHINE_ACCESS_DENIED
CAPACITY_EXCEEDED
INSUFFICIENT_INVENTORY
```

Eso corresponde a las capas de features y al contrato de NexoVending.

El cliente debe preservar, cuando estén disponibles:

* status code;
* response body;
* request ID;
* mensaje técnico útil para debugging.

---

# 10. Response Handling

El cliente debe:

1. ejecutar request;
2. verificar status;
3. capturar response;
4. convertir errores HTTP;
5. devolver una respuesta usable por las capas superiores.

No introducir modelos específicos de NexoVending todavía.

Por ejemplo, este commit **no debe crear**:

```text
MachineResponse
ProductResponse
ReplenishmentResponse
OperatorResponse
```

Esos modelos pertenecerán a las features correspondientes.

---

# 11. Serialization Boundary

La infraestructura debe establecer una frontera clara entre:

```text
HTTP JSON
    ↓
API client
    ↓
feature/data layer
```

El `ApiClient` no debe conocer modelos de dominio.

Debe trabajar con una representación genérica de respuesta.

Las features futuras serán responsables de transformar DTOs en modelos apropiados.

---

# 12. Logging

Crear:

```text
AppLogger
```

como abstracción.

Debe permitir:

```text
debug
info
warning
error
```

Cada evento de networking debe poder registrar:

* método;
* endpoint;
* status;
* request ID;
* duración;
* error cuando corresponda.

No registrar:

* access tokens;
* passwords;
* `id_token`;
* datos sensibles;
* contenido completo de requests que pueda contener información sensible.

El logger debe poder desactivarse o reducirse en producción.

---

# 13. Storage

Crear una abstracción:

```text
LocalStorage
```

para datos locales no sensibles.

Debe permitir como mínimo:

```text
read
write
remove
clear
```

No acoplar la aplicación a una implementación concreta.

---

# 14. Secure Storage

Crear la abstracción:

```text
SecureStorage
```

pero no implementar todavía el flujo de autenticación.

Debe estar preparada para almacenar posteriormente:

```text
access_token
session information
```

La implementación concreta puede utilizar el mecanismo seguro de la plataforma.

**Importante:** este commit no almacena ningún token porque todavía no existe autenticación.

---

# 15. Device Abstractions

Crear interfaces para capacidades que serán implementadas posteriormente.

## ConnectivityService

Debe permitir consultar:

```text
online
offline
unknown
```

No implementar todavía sincronización offline.

## LocationService

Definir la interfaz necesaria para obtener ubicación.

No implementar todavía:

* permisos;
* GPS real;
* geofencing.

## BarcodeScanner

Definir la abstracción para lectura de códigos.

No integrar todavía:

* cámara;
* permisos;
* SDK de barcode.

Estas abstracciones permiten que los commits posteriores sean testeables sin depender directamente del hardware.

---

# 16. Dependency Injection

Establecer una composición central de dependencias.

Conceptualmente:

```text
main
 ↓
AppConfig
 ↓
Logger
 ↓
Storage
 ↓
ApiClient
 ↓
Application
```

Las features no deben crear directamente:

```text
ApiClient()
HttpClient()
SecureStorage()
LocationService()
```

dentro de widgets.

Las dependencias deben ser inyectables.

El mecanismo concreto de dependency injection debe mantenerse simple. No introducir un framework pesado si no es necesario.

---

# 17. Tests

## 17.1 ApiClient

Probar:

* GET exitoso;
* POST exitoso;
* headers;
* `X-Request-Id`;
* base URL;
* timeout;
* status 400;
* status 401;
* status 403;
* status 404;
* status 409;
* status 422;
* status 500;
* response body;
* errores de red;
* errores de serialización;
* generación de request ID.

---

# 18. HTTP Integration Tests

Crear tests contra un servidor HTTP mock/local.

El objetivo es comprobar que:

```text
VendingApp
    ↓
ApiClient
    ↓
HTTP server
```

funciona realmente.

Validar:

* método HTTP;
* URL;
* headers;
* request ID;
* body;
* response;
* status handling.

No utilizar todavía el backend real de NexoVending.

---

# 19. Logging Tests

Probar que:

* eventos HTTP generan logs;
* request ID aparece en los logs;
* status code queda registrado;
* errores quedan registrados;
* tokens y secretos no aparecen.

---

# 20. Storage Tests

Probar mediante una implementación fake:

```text
write
read
remove
clear
```

y validar aislamiento entre claves.

Para `SecureStorage`, probar el contrato utilizando una implementación fake.

No depender todavía del Keychain/Keystore real para la suite unitaria.

---

# 21. Device Abstraction Tests

Crear tests de contrato para:

```text
ConnectivityService
LocationService
BarcodeScanner
```

utilizando implementaciones fake.

Ejemplo:

```text
FakeLocationService
FakeConnectivityService
FakeBarcodeScanner
```

El objetivo es validar que las capas superiores podrán utilizar estas capacidades sin depender del dispositivo real.

---

# 22. Error Tests

Probar que errores de infraestructura se transforman correctamente:

```text
HTTP 401
    ↓
HttpException(statusCode: 401)
```

y:

```text
timeout
    ↓
TimeoutException
```

y:

```text
network failure
    ↓
NetworkException
```

No permitir que errores del paquete HTTP subyacente escapen directamente a la aplicación.

---

# 23. CI

Extender el CI creado en Commit 1.

Debe continuar ejecutando:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

No debe requerir:

* backend;
* PostgreSQL;
* NexoVending;
* credenciales;
* Google account;
* dispositivo físico.

El Commit 2 debe ser completamente reproducible en CI.

---

# 24. Documentación

Actualizar:

```text
README.md
docs/ARCHITECTURE.md
```

y agregar:

```text
docs/NETWORKING.md
```

---

# 25. NETWORKING.md

Documentar:

## API Boundary

```text
VendingApp
    │
    │ HTTPS
    ▼
NexoVending Public API
```

## ApiClient

Responsabilidades:

* HTTP;
* base URL;
* request IDs;
* timeout;
* headers;
* errores.

No responsabilidades:

* autenticación de negocio;
* autorización;
* tenant;
* vending rules;
* inventario.

## Error handling

Documentar la transformación:

```text
HTTP / Network
      ↓
ApiClient
      ↓
Infrastructure Exception
      ↓
Feature/Application
```

## Security

Documentar explícitamente que:

* tokens no se registran;
* passwords no se registran;
* datos sensibles no se registran;
* SecureStorage queda preparado para autenticación posterior.

---

# 26. ARCHITECTURE.md

Actualizar la arquitectura:

```text
VendingApp
│
├── app/
│   ├── router/
│   └── theme/
│
├── core/
│   ├── config/
│   ├── networking/
│   ├── errors/
│   ├── logging/
│   ├── storage/
│   └── device/
│
└── features/
    └── future
```

Establecer:

```text
UI
 ↓
Application
 ↓
Domain
 ↓
Data
 ↓
Core Infrastructure
 ↓
External Systems
```

La infraestructura no debe contener reglas de negocio.

---

# 27. Criterios de aceptación

## CA-01 — HTTP abstraction

Existe un `ApiClient` independiente de las features.

## CA-02 — Base URL

El cliente utiliza `AppConfig.apiBaseUrl`.

## CA-03 — Request ID

Cada request genera o recibe un `X-Request-Id`.

## CA-04 — Timeout

Las requests tienen timeout configurable.

## CA-05 — Error abstraction

Los errores HTTP, de red y timeout no exponen directamente la implementación HTTP subyacente.

## CA-06 — Logging

Existe logging centralizado y no se registran credenciales ni tokens.

## CA-07 — Storage

Existen abstracciones `LocalStorage` y `SecureStorage`.

## CA-08 — Device abstractions

Existen contratos para:

* connectivity;
* location;
* barcode scanner.

## CA-09 — Dependency injection

Las dependencias principales pueden ser reemplazadas por fakes/mocks en tests.

## CA-10 — HTTP tests

Existen tests para requests exitosos, errores HTTP, timeout, red, headers y request IDs.

## CA-11 — Integration tests

El `ApiClient` funciona contra un servidor HTTP de prueba.

## CA-12 — CI

Todo el pipeline continúa pasando:

```text
format
analyze
test
```

## CA-13 — No premature business logic

No existe lógica de:

* autenticación;
* máquinas;
* productos;
* slots;
* reposiciones;
* inventario.

## CA-14 — No real backend dependency

Los tests no dependen de NexoVending real.

## CA-15 — Documentation

Existe documentación de networking, arquitectura y manejo de errores.

---

# 28. Definition of Done

El Commit 2 está terminado cuando:

* [ ] `ApiClient` implementado.
* [ ] Base URL configurada mediante `AppConfig`.
* [ ] HTTP methods implementados.
* [ ] `X-Request-Id` implementado.
* [ ] Timeout configurable implementado.
* [ ] Errores HTTP abstraídos.
* [ ] Errores de red abstraídos.
* [ ] Timeout abstraído.
* [ ] Logging centralizado implementado.
* [ ] No se registran secretos.
* [ ] `LocalStorage` implementado como contrato.
* [ ] `SecureStorage` implementado como contrato.
* [ ] `ConnectivityService` definido.
* [ ] `LocationService` definido.
* [ ] `BarcodeScanner` definido.
* [ ] Dependency injection/composition implementada.
* [ ] Unit tests implementados.
* [ ] HTTP integration tests implementados.
* [ ] Storage tests implementados.
* [ ] Error handling tests implementados.
* [ ] Device abstraction tests implementados.
* [ ] `flutter test` pasa.
* [ ] `flutter analyze` pasa.
* [ ] `dart format` pasa.
* [ ] CI pasa.
* [ ] `NETWORKING.md` creado.
* [ ] `ARCHITECTURE.md` actualizado.
* [ ] README actualizado.
* [ ] No existe autenticación todavía.
* [ ] No existe lógica de vending todavía.
* [ ] No existe dependencia con backend real.
* [ ] No existe acceso directo a Nexo Platform.

---

# 29. Resultado esperado

Al finalizar el Commit 2, VendingApp debe tener esta base:

```text
                         VendingApp
                              │
                    ┌─────────┴─────────┐
                    │                   │
                Application          Core
                                        │
                    ┌───────────────────┼───────────────────┐
                    │                   │                   │
               Networking           Storage             Device
                    │                   │                   │
                    ▼                   ▼                   ▼
              ApiClient          Local/Secure        Connectivity
                    │              Storage             Location
                    │                                  Barcode
                    │
                    ▼
             NexoVending API
```

pero **sin activar todavía la integración funcional con NexoVending**.

El siguiente commit (**Commit 3**) podrá incorporar **Google Sign-In** utilizando estas abstracciones, y el **Commit 4** podrá implementar el intercambio `id_token → /auth/session → Session JWT` sin tener que modificar la fundación de networking.