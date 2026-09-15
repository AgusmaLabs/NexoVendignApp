# Commit 3 — Google Authentication Foundation

## Commit

```text
feat(mobile): implement Google authentication
```

## Objetivo

Implementar la autenticación inicial de VendingApp mediante **Google Sign-In**, utilizando el SDK oficial de Flutter y dejando disponible el `id_token` necesario para que el siguiente commit pueda iniciar una sesión en NexoVending.

El flujo implementado en este commit será exclusivamente:

```text
Flutter
   │
   ▼
Google Sign-In
   │
   ▼
Google account
   │
   ▼
id_token
```

El `id_token` **no se enviará todavía a NexoVending**.

El intercambio:

```text
id_token
   ↓
POST /api/v1/auth/session
   ↓
Session JWT
```

pertenece al **Commit 4**.

---

# 1. Alcance

## Incluye

* Integración del SDK oficial de Google Sign-In para Flutter.
* Abstracción `GoogleSignInService`.
* Modelo de resultado de autenticación.
* Obtención del usuario Google autenticado.
* Obtención del `id_token`.
* Manejo de cancelación.
* Manejo de errores.
* Configuración por ambiente.
* Preparación de configuración Android/iOS.
* UI mínima de autenticación.
* Inyección de dependencias.
* Tests unitarios.
* Tests de widget.
* Tests con fake/mock del proveedor Google.
* Documentación de autenticación.

## No incluye

* `POST /api/v1/auth/session`.
* Session JWT.
* `/operators/me`.
* `Authorization: Bearer`.
* `X-Tenant-Id`.
* Tenant selection.
* Persistencia de sesión.
* SecureStorage de tokens.
* Logout contra NexoVending.
* Autorización de operador.
* Reglas de Vending.
* Google OAuth implementado manualmente.
* Backend authentication.

---

# 2. Arquitectura

La responsabilidad queda separada de la siguiente forma:

```text
┌─────────────────────────────┐
│          VendingApp         │
│                             │
│ Authentication UI           │
│          │                  │
│          ▼                  │
│ GoogleSignInService         │
│          │                  │
└──────────┼──────────────────┘
           │
           ▼
   Google Sign-In SDK
           │
           ▼
      Google Account
           │
           ▼
        id_token
```

El SDK de Google es responsable de la autenticación con Google.

VendingApp **no implementa criptografía OAuth/JWT**.

---

# 3. Authentication Boundary

VendingApp debe tratar Google Sign-In como un proveedor externo.

La aplicación solamente debe obtener:

```text
Google account
id_token
```

y entregar posteriormente ese `id_token` al flujo de sesión de NexoVending.

No implementar:

```text
OAuth authorization code handling
JWT verification
JWT signing
JWT decoding for authorization
cryptographic validation
```

en VendingApp.

La validación de la identidad y la emisión de la sesión pertenecen al backend/Platform según el contrato de autenticación de NexoVending.

---

# 4. Dependencia

Agregar la dependencia oficial de Google Sign-In compatible con la versión Flutter/Dart establecida en Commit 1.

No introducir librerías OAuth alternativas ni implementar un cliente OAuth propio.

La dependencia debe quedar registrada en:

```text
pubspec.yaml
```

y documentada en la arquitectura.

---

# 5. GoogleSignInService

Crear una abstracción:

```text
lib/core/authentication/google_sign_in_service.dart
```

Responsabilidad:

* iniciar Google Sign-In;
* recuperar cuenta autenticada;
* obtener `id_token`;
* cerrar sesión del proveedor cuando corresponda.

Conceptualmente:

```text
GoogleSignInService
├── signIn()
├── getCurrentUser()
└── signOut()
```

El contrato debe ocultar el SDK concreto de Google al resto de la aplicación.

---

# 6. Resultado de autenticación

Crear un modelo específico para representar el resultado:

```text
GoogleAuthenticationResult
```

Debe contener únicamente información necesaria para el siguiente paso.

Como mínimo:

```text
idToken
email
displayName
photoUrl
```

Los datos opcionales deben poder ser `null`.

El `id_token` debe considerarse información sensible.

No incluir información innecesaria del perfil de Google.

---

# 7. Authentication State

Crear un estado mínimo de autenticación para la UI.

Como mínimo:

```text
Unauthenticated
Authenticating
Authenticated
AuthenticationFailure
```

El estado `Authenticated` en este commit significa únicamente:

> Google autenticó correctamente al usuario y VendingApp obtuvo un `id_token`.

No significa todavía:

> El usuario posee una sesión válida en NexoVending.

Esta distinción debe quedar explícita en el código y documentación.

---

# 8. Authentication Controller / Use Case

Crear una capa de aplicación que coordine el flujo:

```text
AuthenticationController
        │
        ▼
GoogleSignInService
        │
        ▼
Google
```

Responsabilidades:

* iniciar autenticación;
* actualizar estado;
* exponer resultado a la UI;
* transformar errores de infraestructura en errores de aplicación.

No debe:

* llamar a NexoVending;
* emitir JWT;
* validar permisos;
* seleccionar tenant.

---

# 9. UI

Crear una pantalla de autenticación mínima.

Conceptualmente:

```text
┌──────────────────────────────┐
│                              │
│        VendingApp            │
│                              │
│   Inicia sesión para         │
│   continuar                  │
│                              │
│   [ Continuar con Google ]   │
│                              │
└──────────────────────────────┘
```

La UI debe manejar:

```text
idle
loading
success
cancelled
error
```

No debe mostrar el `id_token`.

No debe registrar el `id_token`.

No debe persistir el `id_token` todavía.

---

# 10. Cancellation

Si el usuario cancela Google Sign-In:

```text
GoogleSignIn
      ↓
cancelled
      ↓
AuthenticationController
      ↓
Unauthenticated
```

La cancelación no debe tratarse como un error inesperado.

La UI debe permitir volver a intentar.

---

# 11. Error Handling

Los errores del SDK de Google no deben propagarse directamente hacia la UI.

Crear una abstracción de errores de autenticación, por ejemplo:

```text
AuthenticationException
```

con categorías como:

```text
AuthenticationCancelled
AuthenticationFailed
AuthenticationProviderUnavailable
AuthenticationUnknownError
```

La implementación concreta puede mapear los errores específicos del SDK.

La UI solamente debe depender de las excepciones de VendingApp.

---

# 12. Secure Storage

Aunque Commit 2 creó la abstracción:

```text
SecureStorage
```

**no utilizarla todavía para almacenar el `id_token`.**

La razón es arquitectónica:

```text
Commit 3
Google
   ↓
id_token
   ↓
memory only
```

y posteriormente:

```text
Commit 4
id_token
   ↓
/auth/session
   ↓
Session JWT
   ↓
SecureStorage
```

El token de sesión de NexoVending será el que deba persistirse en el siguiente flujo.

No crear persistencia paralela de credenciales Google.

---

# 13. Configuration

La configuración necesaria para Google Sign-In debe quedar separada de:

```text
AppConfig
```

cuando corresponda.

No introducir client IDs directamente dentro de widgets.

La configuración debe poder diferenciar:

```text
development
staging
production
```

si el SDK/plataforma lo requiere.

Los secretos o credenciales que deban pertenecer a la plataforma no deben almacenarse en el repositorio.

---

# 14. Android Configuration

Configurar Android para permitir Google Sign-In.

La configuración debe incluir únicamente los elementos necesarios para que el SDK funcione.

No incluir:

* secretos;
* credenciales privadas;
* archivos sensibles;
* valores específicos de una cuenta personal.

Las configuraciones dependientes del entorno deben documentarse.

---

# 15. iOS Configuration

Configurar iOS para permitir Google Sign-In.

Debe contemplar la configuración requerida por el SDK oficial, incluyendo los valores de aplicación necesarios para el redirect/callback.

No introducir secretos privados en el repositorio.

La configuración debe estar documentada.

---

# 16. Dependency Injection

Actualizar la composición de dependencias:

```text
main
  │
  ├── AppConfig
  ├── Logger
  ├── Storage
  ├── ApiClient
  │
  └── GoogleSignInService
          │
          ▼
      AuthenticationController
```

En producción:

```text
GoogleSignInService
        ↓
Google SDK
```

En tests:

```text
FakeGoogleSignInService
        ↓
deterministic tests
```

La UI nunca debe crear directamente el SDK de Google.

---

# 17. Tests Unitarios

## 17.1 GoogleSignInService contract

Probar:

* login exitoso;
* usuario existente;
* `id_token` disponible;
* cancelación;
* error del proveedor;
* logout.

## 17.2 AuthenticationController

Probar:

```text
Unauthenticated
      ↓
signIn()
      ↓
Authenticating
      ↓
Authenticated
```

y:

```text
Unauthenticated
      ↓
signIn()
      ↓
Authenticating
      ↓
AuthenticationFailure
```

También:

```text
Authenticating
      ↓
cancelled
      ↓
Unauthenticated
```

---

# 18. Token Tests

Validar que:

* un `id_token` válido es entregado al resultado;
* un resultado sin `id_token` no puede considerarse autenticación exitosa;
* el token no se escribe en logs;
* el token no se persiste en `LocalStorage`;
* el token no se persiste en `SecureStorage` en este commit.

El test debe utilizar un token fake.

Nunca utilizar credenciales reales.

---

# 19. Widget Tests

Probar:

### Estado inicial

Se muestra:

```text
Continuar con Google
```

### Loading

Al iniciar autenticación:

```text
Authenticating
```

y el botón no permite múltiples operaciones simultáneas.

### Success

Una autenticación exitosa actualiza el estado.

### Cancellation

La cancelación vuelve al estado no autenticado.

### Error

Se muestra un mensaje de error apropiado.

La UI no debe mostrar:

* tokens;
* excepciones internas;
* detalles del SDK.

---

# 20. Integration Test

Crear un test de integración con el proveedor fake:

```text
Authentication UI
       ↓
AuthenticationController
       ↓
FakeGoogleSignInService
       ↓
GoogleAuthenticationResult
```

Debe validar el flujo completo de la capa móvil sin conectarse a Google real.

No realizar tests automatizados contra cuentas reales de Google.

---

# 21. Tests de regresión

Los tests de Commit 1 y Commit 2 deben continuar pasando:

```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed .
```

El nuevo código no debe romper:

* AppConfig;
* router;
* theme;
* ApiClient;
* logging;
* storage abstractions;
* device abstractions.

---

# 22. Logging

Los eventos de autenticación pueden registrar:

```text
authentication_started
authentication_cancelled
authentication_succeeded
authentication_failed
```

pero nunca:

```text
id_token
access_token
authorization_header
```

Los logs deben conservar información suficiente para diagnosticar fallos sin exponer credenciales.

---

# 23. Documentación

Actualizar:

```text
README.md
docs/ARCHITECTURE.md
```

Agregar:

```text
docs/AUTHENTICATION.md
```

y:

```text
docs/adr/ADR-002-google-sign-in-boundary.md
```

---

# 24. AUTHENTICATION.md

Documentar el flujo actual:

```text
┌──────────────┐
│   VendingApp │
└──────┬───────┘
       │
       │ Google Sign-In
       ▼
┌──────────────┐
│    Google    │
└──────┬───────┘
       │
       │ id_token
       ▼
┌──────────────────────┐
│ Authentication layer │
│      VendingApp      │
└──────────────────────┘
```

Y aclarar que el flujo está deliberadamente incompleto hasta Commit 4:

```text
id_token
   ↓
POST /api/v1/auth/session
```

todavía **no se implementa**.

Documentar también:

* configuración Android;
* configuración iOS;
* manejo de cancelación;
* manejo de errores;
* seguridad;
* testing.

---

# 25. ADR-002 — Google Sign-In Boundary

Crear:

```text
docs/adr/ADR-002-google-sign-in-boundary.md
```

Contenido mínimo:

```markdown
# ADR-002: Google Sign-In Boundary

- Status: Accepted
- Date: 2026-09-14

## Context

VendingApp necesita permitir que el operador se autentique mediante
Google antes de iniciar una sesión en NexoVending.

La autenticación de identidad y la emisión de sesión no deben
implementarse dentro del dominio de VendingApp.

## Decision

VendingApp utilizará el SDK oficial de Google Sign-In exclusivamente
para obtener la identidad autenticada y su `id_token`.

VendingApp no implementará:

- OAuth propio;
- criptografía;
- validación manual de JWT;
- emisión de tokens;
- autorización de operador.

El `id_token` será entregado posteriormente al endpoint de sesión
de NexoVending.

## Current Flow

Google Sign-In
    ↓
Google account
    ↓
id_token

## Next Step

Commit 4 implementará:

id_token
    ↓
POST /api/v1/auth/session
    ↓
NexoVending Session JWT

## Consequences

- Google SDK queda aislado detrás de `GoogleSignInService`.
- Las capas superiores no dependen directamente del SDK.
- Tests pueden utilizar un proveedor fake.
- La aplicación no necesita implementar criptografía.
- El dominio de VendingApp no conoce detalles de OAuth.

## Alternatives Considered

### Implementar OAuth manualmente

Rechazado por complejidad y riesgo innecesario.

### Implementar JWT en VendingApp

Rechazado porque la emisión y validación de sesión pertenecen al
backend/Platform.

### Consumir directamente Google desde el dominio

Rechazado porque introduciría una dependencia externa dentro de
la lógica de aplicación.
```

---

# 26. Criterios de aceptación

## CA-01 — Google Sign-In

VendingApp puede iniciar Google Sign-In mediante el SDK oficial.

## CA-02 — Abstraction

El SDK está aislado detrás de `GoogleSignInService`.

## CA-03 — Successful authentication

Una autenticación exitosa produce un `GoogleAuthenticationResult` con `idToken`.

## CA-04 — Cancellation

La cancelación del usuario no se considera un error inesperado.

## CA-05 — Error handling

Los errores del SDK se transforman en errores propios de VendingApp.

## CA-06 — Authentication state

La UI distingue correctamente:

```text
Unauthenticated
Authenticating
Authenticated
AuthenticationFailure
```

## CA-07 — Token security

El `id_token`:

* no aparece en logs;
* no aparece en mensajes de UI;
* no se almacena en `LocalStorage`;
* no se almacena en `SecureStorage`.

## CA-08 — No backend session

No se realiza ninguna llamada a:

```text
POST /api/v1/auth/session
```

en este commit.

## CA-09 — No JWT

VendingApp no implementa generación, firma o validación propia de JWT.

## CA-10 — Testability

El proveedor Google puede sustituirse por un fake/mock.

## CA-11 — Widget tests

Los escenarios de:

* éxito;
* cancelación;
* error;
* loading

están cubiertos.

## CA-12 — Regression

Los tests de Commit 1 y Commit 2 continúan pasando.

## CA-13 — CI

El pipeline completo continúa pasando:

```text
format
analyze
test
```

## CA-14 — Documentation

Existe documentación actualizada de:

* autenticación;
* arquitectura;
* configuración Google;
* ADR-002.

---

# 27. Definition of Done

El Commit 3 está terminado cuando:

* [ ] Google Sign-In integrado.
* [ ] `GoogleSignInService` creado.
* [ ] Google SDK aislado detrás de la abstracción.
* [ ] `GoogleAuthenticationResult` implementado.
* [ ] Estado de autenticación implementado.
* [ ] Authentication Controller/use case implementado.
* [ ] Pantalla de autenticación creada.
* [ ] Loading implementado.
* [ ] Cancelación implementada.
* [ ] Manejo de errores implementado.
* [ ] Configuración Android realizada.
* [ ] Configuración iOS realizada.
* [ ] `id_token` nunca aparece en logs.
* [ ] `id_token` no se persiste.
* [ ] Tests unitarios implementados.
* [ ] Widget tests implementados.
* [ ] Integration test con fake implementado.
* [ ] Tests anteriores continúan pasando.
* [ ] `flutter test` pasa.
* [ ] `flutter analyze` pasa.
* [ ] `dart format` pasa.
* [ ] CI pasa.
* [ ] `AUTHENTICATION.md` creado.
* [ ] `ARCHITECTURE.md` actualizado.
* [ ] `ADR-002` creado.
* [ ] No existe `/auth/session`.
* [ ] No existe Session JWT.
* [ ] No existe autorización de operador.
* [ ] No existe lógica de vending.

---

# 28. Resultado esperado

Al terminar este commit, VendingApp tendrá:

```text
                         VendingApp
                              │
                    ┌─────────┴──────────┐
                    │                    │
              Application              Core
                    │                    │
                    │          ┌─────────┼─────────┐
                    │          │         │         │
                    │      Networking Storage   Device
                    │
                    ▼
          AuthenticationController
                    │
                    ▼
          GoogleSignInService
                    │
                    ▼
             Google Sign-In
                    │
                    ▼
                 id_token
```

El `id_token` termina en la capa de autenticación de VendingApp.

**Todavía no existe una sesión de NexoVending.**

El siguiente commit (**Commit 4**) tomará exactamente ese resultado y completará:

```text
Google Sign-In
      ↓
id_token
      ↓
POST /api/v1/auth/session
      ↓
Session JWT
      ↓
SecureStorage
      ↓
Authenticated VendingApp session
```
