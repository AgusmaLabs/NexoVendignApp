# Machine Detail and Slots

## Purpose

After a machine is identified, VendingApp loads its detail and physical slot
configuration from NexoVending so the operator has operational context before
replenishment.

```text
MachineSlot represents a physical position/container.
It is not a fixed SKU assignment.
```

## API

```http
GET /api/v1/machines/{machine_id}
Authorization: Bearer <session-jwt>
```

```http
GET /api/v1/machines/{machine_id}/slots
Authorization: Bearer <session-jwt>
```

Both calls use the authenticated `ApiClient`. Detail and slots are loaded
concurrently. If either request fails, the screen stays in `Failure`.

### Machine detail (`MachineOut`)

```json
{
  "machine_id": "…",
  "identifier": "MIX-001",
  "machine_type": "SNACK",
  "name": "Lobby",
  "status": "ACTIVE"
}
```

### Slots (`MachineSlotsOut`)

```json
{
  "machine_id": "…",
  "slots": [
    {
      "slot_id": "…",
      "slot_number": 1,
      "capacity": 10,
      "status": "ACTIVE",
      "preferred_product_id": "…",
      "selling_price": "1500",
      "current_quantity": 4
    }
  ]
}
```

Backend order of `slots` is preserved. The app does not re-sort by `slot_id`.

## Machine Detail

`MachineDetail` is the enriched machine context for the detail screen. It
mirrors the public `MachineOut` fields used after identification.

## Machine Slot

`MachineSlot` is a physical position/container configured by NexoVending.

| Field | Meaning |
| ----- | ------- |
| `slot_id` | Stable slot identity |
| `slot_number` | Physical position (UI label `S{n}`) |
| `capacity` | Backend-configured capacity |
| `status` | Slot operational status |
| `preferred_product_id` | Preferred product configuration (≠ required / currently loaded) |
| `selling_price` | Configured selling price string when present |
| `current_quantity` | Reported quantity when present |

Flutter does **not**:

* invent slots locally;
* filter slots by machine type;
* treat preferred product as the loaded product;
* modify capacity, price, or configuration.

## Empty slots

```text
slots = []
```

is a valid success. The UI shows “No hay slots configurados”. It is not
interpreted as “coffee machine” or any other client-side machine-type rule.

## State management

```text
Initial → Loading → Loaded
Loading → Failure → Retry → Loading
Loading → SessionExpired
```

`Loaded` always contains both `MachineDetail` and `List<MachineSlot>`
(possibly empty). Visual `selectedSlotId` does not call the backend.

Stale responses are ignored: a later `load(B)` supersedes an in-flight
`load(A)` so machine B cannot keep slots from A.

## Error handling

| Status | App handling |
| ------ | ------------ |
| 401 | Clear session → login |
| 403 | Access denied |
| 404 | Machine not found |
| 422 | Validation failure |
| 5xx | Temporary unavailable + retry |
| timeout / network | Recoverable failure + retry |

## Security

* Session JWT only via centralized Bearer attachment.
* Google `id_token` is never sent.
* JWT / Authorization are not logged.
* Tenant and machine access remain NexoVending authority.
* Slot selection is UI state only.

## Related

* [MACHINE_IDENTIFICATION.md](MACHINE_IDENTIFICATION.md)
* [ADR-006](adr/ADR-006-machine-detail-and-slots.md)
* [Mobile API Contract](nexovending_API/Mobile_API_Contract_NexoVending.md)
