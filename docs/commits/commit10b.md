# Commit 10b — Local Backend Connectivity for E2E Verification

## Commit

```text
feat(mobile): enable local backend connectivity for E2E verification
```

> **Nota de numeración.** Este es un commit habilitante fuera de la secuencia de `docs/commits/Plan.md`. No consume el número 11, reservado para el flujo de producto no identificado. La numeración planificada 11 a 27 permanece intacta.

## 1. Objetivo

Permitir que **VendingApp se conecte a un backend NexoVending local** para ejecutar la primera verificación funcional end-to-end de una reposición sobre un dispositivo o emulador Android real.

La aplicación ya implementa el recorrido completo hasta agregar líneas (Commits 1 a 10). El impedimento no es funcional, es de configuración de plataforma:

```text
Android 9+ bloquea tráfico HTTP en claro por defecto.

android/app/src/main/AndroidManifest.xml
    declara INTERNET y CAMERA
    NO declara usesCleartextTraffic
    NO define network_security_config
```

Resultado: cualquier llamada a `http://10.0.2.2:8000` o a la IP LAN del equipo de desarrollo falla a nivel de plataforma, antes de que `HttpApiClient` pueda emitir la request.

Este commit habilita esa conectividad **solo en debug** y documenta la configuración de ejecución.

---

# 2. Alcance

## Incluye

* Manifiesto de debug que permite HTTP en claro únicamente para hosts de desarrollo.
* Documentación de la matriz de `--dart-define` para ejecutar contra un backend local.
* Runbook de verificación sobre dispositivo y emulador.
* Registro de las limitaciones conocidas del recorrido actual.

## Excluye

* Cualquier cambio en `lib/`.
* Cambios en el manifiesto de release.
* Nuevas dependencias.
* Nuevas pantallas o capacidades de negocio.
* Completar o cancelar la reposición: pertenece a los Commits 13 y 14.
* Permiso de ubicación: en `development` y `staging` se usa `FixedLocationService`.

Este commit es **configuración de plataforma y documentación**. Si durante la implementación aparece la necesidad de modificar Dart, es señal de que el problema es otro y debe tratarse aparte.

---

# 3. Regla de seguridad

La habilitación de HTTP en claro es una excepción de desarrollo y debe estar contenida por construcción.

```text
android/app/src/debug/AndroidManifest.xml      →  HTTP en claro permitido
android/app/src/main/AndroidManifest.xml       →  sin cambios
android/app/src/profile/AndroidManifest.xml    →  sin cambios
release                                        →  HTTPS obligatorio
```

Preferir un `network_security_config` limitado a los hosts de desarrollo antes que un `usesCleartextTraffic="true"` global:

```text
10.0.2.2        emulador Android → host
localhost
127.0.0.1
IP LAN del equipo de desarrollo   (documentada, no fija en el repo)
```

Reglas no negociables:

```text
El manifiesto de release NO permite tráfico en claro.

No se fija ninguna IP privada del desarrollador en archivos versionados.

No se agregan certificados, trust anchors ni excepciones de pinning.

No se relaja la validación TLS.

No se agrega ningún camino de login de desarrollo ni inyección
manual de tokens: la sesión sigue emitiéndose por el backend.
```

El último punto importa: el backend acepta una credencial de harness `Bearer principal/<provider>/<subject>`, pero VendingApp **no debe** implementarla. La app sigue obteniendo su sesión por `POST /api/v1/auth/session` con un `id_token` de Google real. La fase de verificación sin Google se ejecuta por HTTP, fuera de la app.

---

# 4. Configuración de ejecución

La app se configura exclusivamente por `--dart-define`, leídos en `lib/main.dart` y materializados en `AppConfig`. No hay flavors de Gradle.

| Define | Valor para E2E local | Nota |
| --- | --- | --- |
| `APP_ENV` | `development` | `production` inyecta `UnsupportedLocationService` y rompe la creación de reposición |
| `API_BASE_URL` | `http://10.0.2.2:8000` | solo host; el default `http://localhost:8080` es incorrecto en Android y apunta a otro puerto |
| `TENANT_ID` | `tenant-a` | debe coincidir con el `--tenant` sembrado en el backend |
| `HTTP_TIMEOUT_MS` | `30000` | |
| `GOOGLE_SERVER_CLIENT_ID` | client ID **Web** de Google Cloud | debe ser idéntico al `GOOGLE_CLIENT_ID` del backend |

## Resolución de URL

`API_BASE_URL` es únicamente el host. Los servicios pasan rutas absolutas que ya incluyen el prefijo de versión, y `HttpApiClient._resolveUri` las combina:

```text
http://10.0.2.2:8000  +  /api/v1/replenishments
        →  http://10.0.2.2:8000/api/v1/replenishments
```

Agregar `/api/v1` al define produce rutas duplicadas. Debe quedar advertido en la documentación.

## Host según destino

```text
Emulador Android       →  http://10.0.2.2:8000
Dispositivo físico     →  http://<IP-LAN-del-PC>:8000
```

Para dispositivo físico, el equipo de desarrollo y el teléfono deben estar en la misma red, y el puerto 8000 accesible desde la LAN (firewall de Windows).

## Google Cloud

```text
OAuth client Web        →  su ID va al backend (GOOGLE_CLIENT_ID)
                           y a la app (GOOGLE_SERVER_CLIENT_ID)

OAuth client Android    →  package com.example.vendingapp
                           SHA-1 del keystore de debug
```

`google-services.json` no es necesario: el proyecto usa `google_sign_in`, no Firebase.

La cuenta de prueba debe tener email verificado, porque el validador de Platform exige `email_verified`.

---

# 5. Runbook de verificación

## Preparación del backend

Según los Commits V13 y V14 de NexoVending:

```text
1. docker compose up -d
2. cadena de migraciones de Platform + cadena de Vending
3. python scripts/seed_e2e.py --tenant tenant-a --subject <google_sub> --with-admin
4. .env con GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET / GOOGLE_REDIRECT_URI
5. GET /health/ready  →  200
```

## Obtención del `google_sub`

El `Operator` se resuelve por `(tenant_id, provider, subject)`, donde `subject` es el `sub` del `id_token`. Ese valor no se conoce antes del primer login.

```text
1. ejecutar la app y autenticarse con la cuenta de prueba
2. POST /auth/session responde 403 OPERATOR_NOT_FOUND
3. obtener el sub decodificando el payload del id_token
   o consultando el endpoint tokeninfo de Google
4. re-ejecutar seed_e2e.py con --subject <google_sub>
5. reintentar el login
```

El paso 3 debe hacerse sin dejar código de depuración que registre el `id_token`: es material de autenticación y no debe quedar en logs, según las reglas de seguridad del repositorio.

## Ejecución

```bash
flutter pub get
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000 \
  --dart-define=TENANT_ID=tenant-a \
  --dart-define=HTTP_TIMEOUT_MS=30000 \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
```

## Recorrido esperado

```text
LoginPage
    ↓  Continuar con Google  →  POST /api/v1/auth/session
OperatorBootstrapPage        →  GET  /api/v1/operators/me
    ↓
OperatorHomePage
    ↓  Identificar máquina
IdentifyMachinePage          →  GET  /api/v1/machines/resolve
    ↓  Ver detalle y slots
MachineDetailPage            →  GET  /api/v1/machines/{id}
                             →  GET  /api/v1/machines/{id}/slots
    ↓  Iniciar reposición
ReplenishmentStartPage       →  POST /api/v1/replenishments          201
    ↓  Escanear producto
ProductLookupPage            →  GET  /api/v1/products/barcode/{code}
    ↓  Continuar
ReplenishmentAddLinePage     →  POST /api/v1/replenishments/{id}/lines  200
    ↓
fin del recorrido disponible en la app
```

El cierre de la reposición (`POST /complete`) se ejecuta por HTTP, fuera de la app.

## Verificaciones a registrar

```text
la sesión persiste tras reiniciar la app          (restore desde secure storage)
la máquina resuelve por code y por UUID interno
los slots muestran capacidad y cantidad actual
el escaneo con cámara funciona en dispositivo físico
el ingreso manual de barcode funciona en emulador
la línea queda reflejada en la respuesta
X-Request-Id presente en cada request
Idempotency-Key presente en POST replenishments y POST lines
Authorization nunca aparece en los logs
```

## Casos de error a ejercitar

```text
backend caído                    →  error de red, sin crash
timeout                          →  mensaje accionable
sesión expirada / JWT inválido   →  401 → vuelta al login
barcode inexistente              →  404 con reintento o ingreso manual
grants revocados en el backend   →  403 presentado sin filtrar detalle interno
cantidad mayor que el stock      →  rechazo del backend presentado al usuario
```

Los mensajes al usuario no deben exponer trazas, errores de base de datos ni detalles de infraestructura.

---

# 6. Tests

Este commit no modifica Dart, por lo que no agrega cobertura de lógica. La validación es de plataforma y de no regresión, y debe reportarse con evidencia.

## Automatizado

```text
flutter analyze        →  sin errores nuevos
dart format --output=none --set-exit-if-changed .
flutter test           →  suite existente sin regresión
```

Además, una verificación del build de release que confirme que el manifiesto fusionado **no** habilita tráfico en claro:

```text
flutter build apk --release
    → inspeccionar el AndroidManifest fusionado
    → usesCleartextTraffic ausente o false
    → networkSecurityConfig de debug ausente
```

Esta comprobación es el único control objetivo de que la excepción quedó contenida en debug.

## Verificación en dispositivo

Obligatoria, porque la capacidad es de plataforma y de hardware:

```text
emulador Android    →  recorrido completo con barcode manual
dispositivo físico  →  recorrido completo con cámara
```

Debe reportarse: destino usado, versión de Android, `API_BASE_URL`, resultado de cada paso del recorrido y de cada caso de error.

## Regla de evidencia

No declarar el commit terminado por inspección de código. Debe reportarse:

```text
resultado de flutter analyze
resultado de dart format
resultado de flutter test
inspección del manifiesto de release
verificación en emulador
verificación en dispositivo físico
```

---

# 7. Documentación

## Nuevo

`docs/E2E_LOCAL_RUN.md`:

* matriz de `--dart-define` y qué hace cada uno;
* advertencia de que `API_BASE_URL` es solo host;
* host según emulador o dispositivo físico;
* por qué `APP_ENV=production` rompe la creación de reposición;
* configuración de Google Cloud y equivalencia de client IDs;
* procedimiento de obtención del `google_sub`;
* runbook completo y casos de error;
* alcance del recorrido disponible y cierre por HTTP.

Tabla de diagnóstico a incluir:

| Síntoma | Causa probable |
| --- | --- |
| falla de red inmediata en toda llamada | tráfico en claro no permitido, o manifiesto de debug ausente |
| conexión rechazada | `API_BASE_URL` apunta a `localhost` en lugar de `10.0.2.2`, o puerto incorrecto |
| 404 en todas las rutas | `/api/v1` duplicado en `API_BASE_URL` |
| login de Google falla sin llegar al backend | falta el OAuth client Android o el SHA-1 no coincide |
| `POST /auth/session` devuelve 503 | el backend no tiene las variables de Google configuradas |
| `POST /auth/session` devuelve 403 | no hay `Operator` para `(tenant, google, sub)` |
| 403 en rutas de negocio tras login exitoso | grants no otorgados, o `TENANT_ID` distinto del sembrado |
| excepción al iniciar reposición | `APP_ENV=production` con `UnsupportedLocationService` |
| dispositivo físico no alcanza el backend | red distinta o firewall bloqueando el puerto 8000 |

## Actualizaciones

| Documento | Cambio |
| --- | --- |
| `README.md` | sección de ejecución contra backend local y estado del recorrido E2E |
| `docs/REPLENISHMENT.md` | registrar que el cierre de la reposición se ejecuta por HTTP en esta etapa |
| `docs/commits/Plan.md` | nota de que 10b es habilitante y no altera la numeración 11 a 27 |

---

# 8. Criterios de aceptación

## Configuración de plataforma

* Existe manifiesto de debug que permite HTTP en claro.
* El alcance está limitado a hosts de desarrollo.
* El manifiesto de `main` no fue modificado.
* El build de release no permite tráfico en claro.
* No se versionó ninguna IP privada del desarrollador.
* No se agregaron certificados ni excepciones de TLS.

## Ejecución

* La app se conecta al backend local desde emulador.
* La app se conecta al backend local desde dispositivo físico.
* El recorrido login → operador → máquina → slots → reposición → producto → línea se completa.
* La sesión se restaura tras reiniciar la app.
* `X-Request-Id` e `Idempotency-Key` presentes donde corresponde.
* Ningún token ni encabezado de autorización aparece en los logs.

## No regresión

* `lib/` sin cambios.
* Sin dependencias nuevas.
* `flutter analyze` sin errores nuevos.
* `dart format` sin diferencias.
* Suite de tests existente pasa.

## Arquitectura y seguridad

* No se implementó la credencial de harness del backend en la app.
* No se agregó login de desarrollo ni inyección manual de tokens.
* No se duplicó lógica de negocio del backend.
* La separación presentación / dominio / datos no cambió.
* Los errores presentados al usuario no filtran detalles internos.

## Documentación

* `docs/E2E_LOCAL_RUN.md` existe y cubre el runbook completo.
* Las limitaciones conocidas están declaradas como tales.
* No se documenta como implementado nada que no lo esté.

---

# 9. Definition of Done

```text
backend NexoVending local  (V13 + V14 aplicados, escenario sembrado)
     │
     ▼
flutter run  con los dart-define de desarrollo
     │
     ├── login con Google                     →  sesión emitida y almacenada
     ├── operador cargado                     →  rol y estado correctos
     ├── máquina identificada por code        →  detalle y slots visibles
     ├── reposición iniciada                  →  IN_PROGRESS
     ├── producto resuelto por barcode        →  cámara y manual
     └── línea agregada                       →  reflejada en la respuesta
     │
     ▼
POST /complete por HTTP                       →  COMPLETED
     │
     ▼
inventario verificado en el backend
     │
     ▼
build de release inspeccionado                →  sin tráfico en claro
```

### Secuencia

```text
VendingApp
Commit 10  (líneas de reposición)
  │
  │ Commit 10b — habilitante
  ▼
conectividad con backend local verificada en dispositivo
  │
  ▼
Commit 11  (flujo de producto no identificado)
  ▼
Commit 12  (revisión)
  ▼
Commit 13  (completar reposición)
  │
  └── recién aquí la reposición se cierra desde la app
```

Regla resultante:

> **VendingApp puede ejecutarse contra un backend NexoVending local y recorrer la reposición hasta agregar líneas; el cierre sigue siendo por HTTP hasta el Commit 13, y la excepción de tráfico en claro nunca alcanza un build de release.**
