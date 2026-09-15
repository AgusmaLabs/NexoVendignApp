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
