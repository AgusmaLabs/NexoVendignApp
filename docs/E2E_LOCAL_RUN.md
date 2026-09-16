# Local E2E run (Commit 10b + established emulator)

Status: **Implemented**. Enabling work outside the numbered `Plan.md` sequence
(does not consume Commit 11).

This document is the **established local lab** for Android + Google Sign-In +
NexoVending after the first successful end-to-end replenishment on this machine.

## Established lab (this workstation)

| Piece | Value |
| --- | --- |
| AVD name | `nexo_e2e_api35` |
| Device profile | Pixel 6 |
| System image | `system-images;android-35;google_apis;x86_64` |
| App package | `com.example.vendingapp` |
| Debug SHA-1 | `4F:AD:F8:9B:1D:5C:85:83:25:C3:65:AE:67:17:EF:F9:73:68:3A:AF` |
| Emulator → API | `http://10.0.2.2:8000` |
| Tenant | `tenant-a` |
| Machine code | `MIX-001` |
| Product barcode | `7800001` |
| Slot | `7` |
| Backend | `NexoVending` via `docker compose` (Postgres + `vending-api`) |

Native packaging required for this emulator (already in the repo):

- `android/app/src/debug/AndroidManifest.xml` → `extractNativeLibs=true` + cleartext
- `android/app/build.gradle.kts` → `packaging.jniLibs.useLegacyPackaging = true`

Do **not** wipe the AVD unless necessary. Recreating it loses Google accounts and
Play Services state; prefer cold boot / app reinstall.

## One-command app launch

From `NexoVendingApp`:

```powershell
pwsh -File scripts/ensure_e2e_avd.ps1   # only if AVD missing
pwsh -File scripts/run_e2e_android.ps1
```

`run_e2e_android.ps1`:

1. Starts `nexo_e2e_api35` if no device is connected.
2. Reads `GOOGLE_CLIENT_ID` from `../NexoVending/.env`.
3. Runs `flutter run` with the dart-defines below.

## Dart defines

| Define | Local E2E value | Notes |
| --- | --- | --- |
| `APP_ENV` | `development` | `production` breaks replenishment create (unsupported location) |
| `API_BASE_URL` | `http://10.0.2.2:8000` | host only — do **not** append `/api/v1` |
| `TENANT_ID` | `tenant-a` | must match `seed_e2e.py --tenant` |
| `HTTP_TIMEOUT_MS` | `30000` | |
| `GOOGLE_SERVER_CLIENT_ID` | Web OAuth client ID | must match backend `GOOGLE_CLIENT_ID` |

### Host by target

```text
Android emulator     →  http://10.0.2.2:8000
Physical device      →  http://<LAN-IP-of-PC>:8000
```

## Backend (NexoVending)

```powershell
cd ..\NexoVending
# Important: container DB host must be "postgres", not localhost from a host shell env.
$env:DATABASE_URL = 'postgresql+psycopg://vending:vending@postgres:5432/vending'
docker compose up -d --build
```

Seed harness operator (HTTP-only tests):

```powershell
pwsh -File scripts/seed_e2e_docker.ps1 -Subject e2e-1 -WithAdmin
```

After the first Google Sign-In, the app logs `googleSubject` (opaque Google
`sub`). Re-seed that subject so `/auth/session` accepts the account:

```powershell
pwsh -File scripts/seed_e2e_docker.ps1 -Subject <googleSubject> -WithAdmin
```

Prefer `seed_e2e_docker.ps1` over host `python scripts/seed_e2e.py`: the API
container has the Platform version the app actually runs.

See NexoVending `docs/E2E_REPLENISHMENT.md`.

## Google Cloud (OAuth)

| Client type | Purpose | Notes |
| --- | --- | --- |
| Web application | Backend `GOOGLE_CLIENT_ID` + Flutter `GOOGLE_SERVER_CLIENT_ID` | IDs **must match** |
| Android | Google Sign-In on device | Package `com.example.vendingapp` + debug SHA-1 above |

Same GCP project for Web + Android. If Consent Screen is **Testing**, add every
Google account used on the emulator as a test user.

Regenerate SHA-1 only if the debug keystore is recreated:

```bash
keytool -list -v -alias androiddebugkey \
  -keystore %USERPROFILE%\.android\debug.keystore \
  -storepass android -keypass android
```

Populate NexoVending `.env` from `.env.example` (`GOOGLE_*`, `JWT_*`), then
rebuild/restart the API.

## Happy path (app + HTTP complete)

1. Backend up + seed with real `googleSubject` (after first login once).
2. `pwsh -File scripts/run_e2e_android.ps1`
3. Continuar con Google → operador listo.
4. **Identificar e iniciar** → código `MIX-001` (resolve + slots + create in one step).
5. En la misma pantalla de reposición: producto `7800001` → slot → cantidad → agregar línea → siguiente.
6. Complete via HTTP (until Commit 13 UI exists):

```powershell
cd ..\NexoVending
pwsh -File scripts/complete_replenishment.ps1 `
  -ReplenishmentId <id from flutter log replenishment_create_succeeded> `
  -Subject <googleSubject>
```

Primary field path (after this UX consolidation):

```text
Identificar máquina  →  Reposición (líneas en loop)
```

Legacy intermediate routes (`/machines/detail`, `/replenishments/start`,
`/products/lookup`, `/replenishments/lines/add`) remain registered but are not
part of the default operator path.
## Recreate AVD (only if corrupted)

```powershell
pwsh -File scripts/ensure_e2e_avd.ps1
# If an old broken AVD blocks creation:
#   emulator -list-avds
#   avdmanager delete avd -n nexo_e2e_api35
#   pwsh -File scripts/ensure_e2e_avd.ps1
```

Then re-add a Google account on the emulator and confirm Android OAuth client
SHA-1 still matches the debug keystore.

## Diagnostics

| Symptom | Likely cause |
| --- | --- |
| MainActivity / empty native libs on emulator | missing `useLegacyPackaging` / `extractNativeLibs` |
| Immediate network failure | cleartext blocked / not a debug build |
| Connection refused | wrong host (`localhost` on device) or API down |
| Compose API unhealthy | host `DATABASE_URL` points at `localhost` — force `@postgres` for compose |
| 404 on all routes | `/api/v1` duplicated in `API_BASE_URL` |
| Google login never hits backend | Android OAuth client / SHA-1 mismatch |
| Account picker / password OK, then back to login | CredMan maps OAuth misconfig as cancel — Android client + SHA-1 + test users |
| Log `authentication_cancelled` with `[16]` / `Account reauth failed` | Android OAuth client missing/wrong; or GMS account reauth — clear GMS data only as last resort |
| `503` on `/auth/session` | backend Google env missing |
| `403` / “no tienes acceso a este tenant” | seed missing for that `googleSubject` |
| Exception starting replenishment | `APP_ENV=production` |

## Related

- NexoVending `docs/E2E_REPLENISHMENT.md` — seed + harness HTTP
- NexoVending `scripts/seed_e2e_docker.ps1` — seed inside API container
- NexoVending `scripts/complete_replenishment.ps1` — HTTP complete
- NexoVendingApp `scripts/ensure_e2e_avd.ps1` / `run_e2e_android.ps1`
