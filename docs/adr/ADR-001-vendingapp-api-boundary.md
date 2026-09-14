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
