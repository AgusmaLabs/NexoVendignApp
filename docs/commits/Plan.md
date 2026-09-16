
> **Nota:** los commits habilitantes `10b` (cleartext/E2E lab) y `10c` (flujo de
> campo condensado) viven fuera de esta numeración y no desplazan los commits 11–27.
> Ver [commit10b.md](commit10b.md), [../E2E_LOCAL_RUN.md](../E2E_LOCAL_RUN.md).

| Estado | Commit | Concepto | Título | Breve descripción |
| :---: | :---: | :------------------ | :--------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------ |
| [x] | **1** | Fundación | `feat(mobile): bootstrap VendingApp Flutter foundation` | Crear el proyecto Flutter, estructura base, configuración de ambientes, dependencias, navegación inicial, tema y ejecución mínima. |
| [x] | **2** | Fundación | `feat(mobile): introduce application infrastructure` | Implementar networking base, configuración de API, manejo de errores, logging, request IDs, almacenamiento local y abstracciones de dispositivo. |
| [x] | **3** | Identidad | `feat(mobile): implement Google authentication` | Integrar Google Sign-In en Flutter y obtener el `id_token`, sin implementar OAuth/JWT en la aplicación. |
| [x] | **4** | Identidad | `feat(mobile): implement Vending session` | Consumir `POST /api/v1/auth/session`, almacenar el Session JWT de forma segura, restaurar sesión y cerrar sesión. |
| [x] | **5** | Identidad | `feat(mobile): implement operator bootstrap` | Consumir `/operators/me`, cargar el operador autenticado y establecer el contexto operativo de VendingApp. |
| [x] | **6** | Operación | `feat(mobile): implement machine identification` | Implementar identificación de máquinas mediante QR e identificador interno utilizando la API de NexoVending. |
| [x] | **7** | Operación | `feat(mobile): implement machine detail and slots` | Consultar máquina y slots físicos, mostrando configuración y cantidades disponibles según ADR-014. |
| [x] | **8** | Reposición | `feat(mobile): implement replenishment creation` | Crear una reposición capturando máquina, timestamp y ubicación GPS mediante `POST /replenishments`. |
| [x] | **9** | Reposición | `feat(mobile): implement barcode product lookup` | Integrar cámara/lector de código de barras y consulta de productos mediante la API. |
| [x] | **10** | Reposición | `feat(mobile): implement replenishment lines` | Agregar productos, cantidades, slots, precios, timestamps y sustituciones a una reposición. |
| [x] | **10c** | UX campo | `feat(mobile): condense replenishment field flow` | Colapsar identify/detail/start/lookup/add-line en: identificar+iniciar visita → pantalla única de líneas en loop. Fuera de la numeración 11–27. |
| [ ] | **11** | Reposición | `feat(mobile): implement unresolved product workflow` | Implementar el flujo de producto no identificado mediante `PENDING_PRODUCT_RESOLUTION`, sin crear productos desde la aplicación. |
| [ ] | **12** | Reposición | `feat(mobile): implement replenishment review` | Crear la pantalla de revisión de la operación antes de completarla, incluyendo líneas, cantidades, slots, sustituciones y pendientes. |
| [ ] | **13** | Reposición | `feat(mobile): implement replenishment completion` | Completar la reposición mediante la API y mostrar el resultado de la operación y sus movimientos generados por backend. |
| [ ] | **14** | Reposición | `feat(mobile): implement replenishment cancellation` | Implementar cancelación, confirmación y manejo de estados finales de una reposición. |
| [ ] | **15** | Robustez | `feat(mobile): implement idempotent operations` | Gestionar `Idempotency-Key` en operaciones críticas, persistiendo claves para permitir reintentos seguros. |
| [ ] | **16** | Robustez | `feat(mobile): implement network and session resilience` | Manejar expiración de sesión, errores HTTP, timeouts, pérdida de conectividad y reintentos sin duplicar operaciones. |
| [ ] | **17** | Robustez | `feat(mobile): implement operational recovery` | Recuperar el estado de una reposición en curso después de cierre inesperado, interrupción o reinicio de la aplicación. |
| [ ] | **18** | Producto | `feat(mobile): implement replenishment history` | Incorporar consulta y visualización del historial de reposiciones y sus estados. |
| [ ] | **19** | Producto | `feat(mobile): complete field operations UX` | Consolidar navegación, estados de carga, errores, confirmaciones, feedback y UX orientada al trabajo en terreno. |
| [ ] | **20** | Calidad | `test(mobile): establish unit and widget test foundation` | Crear la estrategia y primera cobertura sistemática de unit tests, casos de uso, estado y widgets. |
| [ ] | **21** | Calidad | `test(mobile): implement API contract integration tests` | Validar la integración de VendingApp con los contratos HTTP reales de NexoVending. |
| [ ] | **22** | Calidad | `test(mobile): implement replenishment end-to-end flow` | Probar de extremo a extremo login → operador → máquina → slots → producto → reposición → completar. |
| [ ] | **23** | Seguridad | `feat(mobile): harden security and observability` | Revisar almacenamiento seguro, manejo de sesión, logs, datos sensibles, request tracing y errores. |
| [ ] | **24** | Arquitectura futura | `feat(mobile): prepare offline-aware architecture` | Preparar la aplicación para futuras capacidades offline sin implementar un inventario paralelo ni sincronización completa en V1. |
| [ ] | **25** | Release | `chore(mobile): establish production build pipeline` | Configurar builds Android/iOS, ambientes, versionado, CI/CD, secrets y validaciones de release. |
| [ ] | **26** | Release | `docs(mobile): finalize V1 technical documentation` | Consolidar arquitectura, API, autenticación, testing, configuración, troubleshooting y guía de desarrollo. |
| [ ] | **27** | Release | `release(mobile): VendingApp V1` | Ejecutar validación final, suite completa, smoke/E2E, build productivo y cierre formal de V1. |
