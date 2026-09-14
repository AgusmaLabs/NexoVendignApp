# Commit 1 — Bootstrap VendingApp Flutter Foundation

## Commit

```text
feat(mobile): bootstrap VendingApp Flutter foundation
```

## Objetivo

Crear la fundación técnica inicial del repositorio **VendingApp**, estableciendo:

* proyecto Flutter;
* estructura arquitectónica inicial;
* configuración de aplicación;
* navegación base;
* tema visual;
* punto de entrada;
* dependencias mínimas;
* base de testing;
* análisis estático;
* CI;
* documentación arquitectónica inicial.

Este commit **no implementa funcionalidades de negocio ni integración con NexoVending**.

VendingApp debe quedar como una aplicación Flutter ejecutable, testeada y preparada para incorporar progresivamente autenticación, operaciones de vending y consumo de la API pública de NexoVending.

---

# 1. Alcance

## Incluye

* Bootstrap del proyecto Flutter.
* Null safety.
* Estructura inicial `app/` y `core/`.
* `VendingApp`.
* `AppRouter`.
* `AppTheme`.
* `AppConfig`.
* Pantalla inicial placeholder.
* Tests unitarios/widget/smoke.
* `flutter analyze`.
* Formateo.
* CI básico.
* README.
* Documentación de arquitectura.
* ADR de frontera VendingApp → NexoVending.

## No incluye

* Google Sign-In.
* OAuth.
* JWT.
* `/auth/session`.
* `/operators/me`.
* QR.
* Barcode.
* GPS.
* Máquinas.
* Slots.
* Productos.
* Reposiciones.
* Inventario.
* Networking contra NexoVending.
* Persistencia de sesión.
* Offline.
* Acceso directo a Nexo Platform.

---

# 2. Estructura inicial

Crear la siguiente estructura:

```text
vending_app/
├── android/
├── ios/
├── lib/
│   ├── app/
│   │   ├── app.dart
│   │   ├── router/
│   │   │   └── app_router.dart
│   │   └── theme/
│   │       └── app_theme.dart
│   │
│   ├── core/
│   │   └── config/
│   │       └── app_config.dart
│   │
│   └── main.dart
│
├── test/
│   ├── app/
│   │   ├── router/
│   │   └── theme/
│   │
│   └── core/
│       └── config/
│
├── docs/
│   ├── ARCHITECTURE.md
│   └── adr/
│       └── ADR-001-vendingapp-api-boundary.md
│
├── .github/
│   └── workflows/
│       └── ci.yml
│
├── analysis_options.yaml
├── pubspec.yaml
├── README.md
└── .gitignore
```

No crear todavía directorios de features que pertenecen a commits posteriores:

```text
authentication/
operator/
machines/
products/
replenishments/
networking/
storage/
device/
```

---

# 3. Bootstrap Flutter

Crear una aplicación Flutter válida utilizando null safety.

La versión de Flutter/Dart utilizada debe quedar:

* fijada mediante la configuración correspondiente; o
* explícitamente documentada.

El proyecto debe poder ejecutarse al menos en modo desarrollo.

Debe ser posible ejecutar:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

sin errores.

---

# 4. Application Shell

Crear:

```text
lib/app/app.dart
```

con `VendingApp` como punto central de composición de la aplicación.

`VendingApp` debe centralizar:

* aplicación Material;
* theme;
* router;
* configuración global futura.

La lógica de negocio no debe residir en `VendingApp`.

Arquitectura inicial:

```text
main.dart
    │
    ▼
VendingApp
    │
    ├── AppTheme
    │
    └── AppRouter
```

---

# 5. Main

`lib/main.dart` debe tener responsabilidad mínima.

Debe:

1. inicializar el bootstrap mínimo necesario;
2. construir `VendingApp`.

No introducir lógica de negocio en `main.dart`.

Conceptualmente:

```text
main()
  ↓
bootstrap
  ↓
VendingApp
```

---

# 6. Router

Crear:

```text
lib/app/router/app_router.dart
```

Debe existir un mecanismo centralizado de navegación desde el primer commit.

Inicialmente debe existir como mínimo:

```text
/
```

que apunte a una pantalla inicial/placeholder.

La navegación futura deberá poder agregar rutas sin cambiar el mecanismo arquitectónico.

No implementar todavía:

```text
/login
/operator
/machines
/replenishments
```

---

# 7. Theme

Crear:

```text
lib/app/theme/app_theme.dart
```

Debe proporcionar un `ThemeData` centralizado.

Como mínimo debe definir:

* `ColorScheme`;
* tipografía base;
* estilos generales de Material;
* configuración visual global necesaria para la aplicación inicial.

Las futuras features no deben crear su propio `ThemeData` global.

El diseño visual definitivo de VendingApp queda fuera de este commit.

---

# 8. AppConfig

Crear:

```text
lib/core/config/app_config.dart
```

Debe introducir una abstracción de configuración de aplicación.

Como mínimo debe contemplar:

```text
environment
apiBaseUrl
```

Los valores deben poder ser proporcionados externamente a la aplicación y no deben estar hardcodeados dentro de widgets o features.

Ambientes previstos:

```text
development
staging
production
```

No es necesario implementar todavía diferentes despliegues productivos.

No realizar llamadas HTTP en este commit.

La configuración debe quedar preparada para que el Commit 2 incorpore networking.

---

# 9. Pantalla inicial

Crear una pantalla inicial mínima que permita comprobar que:

* Flutter arrancó;
* `VendingApp` fue construido;
* el router funciona;
* el theme fue aplicado.

La pantalla puede ser un placeholder de VendingApp.

No debe contener lógica de vending.

---

# 10. Testing

Crear una base de testing real para el proyecto.

## 10.1 App

Probar que:

* `VendingApp` puede construirse;
* la aplicación inicia;
* la ruta inicial existe;
* la pantalla inicial se renderiza.

## 10.2 Router

Probar:

* ruta `/`;
* navegación inicial;
* comportamiento ante una ruta inexistente, según la estrategia elegida.

## 10.3 Theme

Probar que:

* `AppTheme` puede construirse;
* existe un `ColorScheme`;
* la aplicación utiliza el theme definido.

## 10.4 AppConfig

Probar que:

* la configuración puede construirse;
* `environment` se conserva correctamente;
* `apiBaseUrl` se conserva correctamente;
* `apiBaseUrl` no puede quedar vacío cuando corresponda;
* la configuración puede ser inyectada sin modificar la UI.

---

# 11. Smoke Test

Agregar al menos un smoke/widget test que valide:

```text
VendingApp
    ↓
arranque
    ↓
render inicial
    ↓
sin excepciones
```

El objetivo es disponer desde el primer commit de una prueba que valide la aplicación como un todo.

---

# 12. Static Analysis

Configurar el proyecto para que:

```bash
flutter analyze
```

termine sin errores.

También debe mantenerse el código formateado mediante:

```bash
dart format --output=none --set-exit-if-changed .
```

No se deben introducir excepciones innecesarias a las reglas de análisis.

---

# 13. CI

Crear:

```text
.github/workflows/ci.yml
```

El pipeline debe ejecutar como mínimo:

```text
checkout
    ↓
setup Flutter
    ↓
flutter pub get
    ↓
dart format --output=none --set-exit-if-changed .
    ↓
flutter analyze
    ↓
flutter test
```

El CI debe fallar si cualquiera de estas etapas falla.

No es necesario implementar todavía builds Android/iOS de producción.

---

# 14. README

Crear `README.md` documentando:

## Propósito

VendingApp es la aplicación móvil utilizada por los operadores de reposición de NexoVending.

## Arquitectura

```text
VendingApp
    │
    │ HTTPS / Public API
    ▼
NexoVending
```

VendingApp es un cliente externo.

No debe acceder directamente a:

* base de datos de NexoVending;
* repositorios backend;
* infraestructura interna;
* Nexo Platform.

## Desarrollo

Documentar:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Estado

Indicar que este commit corresponde a la fundación inicial y que las funcionalidades de negocio serán incorporadas progresivamente.

---

# 15. Architecture Documentation

Crear:

```text
docs/ARCHITECTURE.md
```

Debe establecer desde el comienzo la dirección arquitectónica:

```text
Presentation
      ↓
Application
      ↓
Domain
      ↓
Data
      ↓
External
```

La arquitectura inicial puede contener solamente las capas que realmente existen.

No crear capas vacías únicamente para satisfacer el diagrama.

Establecer también:

```text
VendingApp
    │
    ▼
NexoVending Public API
```

y:

```text
VendingApp
    X
    └──> Nexo Platform internal APIs
```

La aplicación no debe consumir directamente Nexo Platform.

---

# 16. ADR-001 — API Boundary

Crear:

```text
docs/adr/ADR-001-vendingapp-api-boundary.md
```

Contenido mínimo:

```markdown
# ADR-001: VendingApp API Boundary

- Status: Accepted
- Date: 2026-09-14

## Context

VendingApp es un cliente móvil independiente del backend NexoVending.

El backend contiene las reglas de negocio, autorización operacional,
multi-tenancy, inventario y persistencia.

## Decision

VendingApp consumirá las capacidades de negocio de vending exclusivamente
mediante la API pública de NexoVending.

VendingApp no accederá directamente a:

- base de datos;
- repositorios;
- infraestructura interna;
- Nexo Platform;
- APIs privadas del backend.

## Consequences

- La API HTTP de NexoVending constituye el boundary entre móvil y backend.
- Los contratos HTTP son la fuente de integración.
- VendingApp no duplicará reglas de negocio del backend.
- Los modelos internos de Python no serán compartidos con Flutter.
- Los cambios de backend que afecten al móvil deberán reflejarse mediante
  contratos API versionados.

## Alternatives considered

### Acceso directo a Nexo Platform

Rechazado porque rompería el boundary de NexoVending y permitiría que
el cliente móvil dependiera de infraestructura que no le pertenece.

### Acceso directo a la base de datos

Rechazado porque eliminaría la autoridad del backend sobre las reglas
de negocio, autorización y aislamiento por tenant.
```

---

# 17. Criterios de aceptación

## CA-01 — Proyecto

Existe un proyecto Flutter válido, compilable y ejecutable.

## CA-02 — Application Shell

`VendingApp` está implementado como composición central de:

* router;
* theme;
* configuración.

## CA-03 — Main

`main.dart` no contiene lógica de negocio.

## CA-04 — Router

Existe un router centralizado y la ruta inicial funciona.

## CA-05 — Theme

Existe un theme centralizado utilizado por la aplicación.

## CA-06 — Configuration

Existe `AppConfig` y la configuración no está hardcodeada dentro de widgets/features.

## CA-07 — Initial Screen

La aplicación muestra correctamente una pantalla inicial.

## CA-08 — Tests

Los tests unitarios/widget/smoke definidos para el commit pasan.

## CA-09 — Analysis

```bash
flutter analyze
```

termina sin errores.

## CA-10 — Formatting

```bash
dart format --output=none --set-exit-if-changed .
```

termina correctamente.

## CA-11 — CI

El pipeline ejecuta correctamente:

```text
flutter pub get
format
analyze
test
```

## CA-12 — Documentation

Existen:

```text
README.md
docs/ARCHITECTURE.md
docs/adr/ADR-001-vendingapp-api-boundary.md
```

## CA-13 — API Boundary

La documentación establece que VendingApp consume NexoVending mediante API pública.

## CA-14 — Scope

No existen implementaciones de:

* autenticación;
* Google Sign-In;
* JWT;
* networking;
* QR;
* barcode;
* GPS;
* máquinas;
* slots;
* productos;
* reposiciones;
* inventario.

---

# 18. Definition of Done

El Commit 1 está terminado cuando:

* [ ] Proyecto Flutter creado.
* [ ] Null safety habilitado.
* [ ] Versión Flutter/Dart documentada o fijada.
* [ ] `VendingApp` implementado.
* [ ] `main.dart` reducido al bootstrap.
* [ ] Router centralizado implementado.
* [ ] Theme centralizado implementado.
* [ ] `AppConfig` implementado.
* [ ] Pantalla inicial funcionando.
* [ ] Tests unit/widget/smoke implementados.
* [ ] `flutter test` pasa.
* [ ] `flutter analyze` pasa.
* [ ] `dart format` pasa.
* [ ] CI configurado.
* [ ] CI pasa.
* [ ] `README.md` creado.
* [ ] `docs/ARCHITECTURE.md` creado.
* [ ] `ADR-001-vendingapp-api-boundary.md` creado.
* [ ] No existe lógica de negocio de vending.
* [ ] No existe integración con NexoVending todavía.
* [ ] No existe acceso directo a Nexo Platform.
* [ ] No existen dependencias prematuras de features futuras.

---

# 19. Resultado esperado

Al finalizar el commit debe ser posible ejecutar:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

y obtener una aplicación VendingApp funcional a nivel de fundación.

El resultado debe ser:

```text
┌───────────────────────────┐
│       VendingApp          │
│                           │
│   Application Shell       │
│   Router                  │
│   Theme                   │
│   Configuration           │
│                           │
│   Tests + CI              │
└───────────────────────────┘
```

sin implementar todavía ninguna capacidad de negocio.

El siguiente commit será responsable de introducir la **infraestructura de aplicación**: networking, manejo de errores, logging, request IDs, almacenamiento y abstracciones de dispositivo.
