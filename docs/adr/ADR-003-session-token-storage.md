# ADR-003: Session Token Storage

- Status: Accepted
- Date: 2026-09-15

## Context

VendingApp recibe un Session JWT desde NexoVending después de completar
el flujo de autenticación.

El token debe sobrevivir al reinicio de la aplicación sin quedar
expuesto mediante almacenamiento común o logs.

## Decision

El Session JWT será almacenado exclusivamente mediante la abstracción
SecureStorage.

VendingApp no almacenará el Session JWT en:

- LocalStorage;
- SharedPreferences;
- archivos de texto;
- bases de datos locales no cifradas;
- logs.

## Lifecycle

Google id_token
    ↓
POST /api/v1/auth/session
    ↓
Session JWT
    ↓
SecureStorage
    ↓
restore on startup
    ↓
Authenticated session

## Consequences

- La sesión puede sobrevivir al reinicio de la aplicación.
- El token queda aislado del almacenamiento general.
- La infraestructura puede utilizar Keychain/Keystore u otro mecanismo
  seguro de plataforma.
- Los tests pueden utilizar una implementación fake de SecureStorage.

## Security

El Session JWT nunca debe aparecer en:

- logs;
- mensajes de error;
- UI;
- analytics;
- crash reports.
