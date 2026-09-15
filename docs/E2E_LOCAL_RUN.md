# Local E2E run (Commit 10b)

Status: **Implemented** (debug cleartext + runbook). Enabling work outside the
numbered Plan.md sequence (does not consume Commit 11).

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

## Cleartext HTTP (debug only)

`android/app/src/debug/` enables cleartext via `network_security_config` and
`usesCleartextTraffic`. Release builds do not include that overlay.

## Run

```bash
flutter pub get
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000 \
  --dart-define=TENANT_ID=tenant-a \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
```

## Backend prep

See NexoVending `docs/E2E_REPLENISHMENT.md` (V13 + V14). After first Google
login, re-seed with the real Google `sub`:

```bash
python scripts/seed_e2e.py --tenant tenant-a --subject <google_sub> --with-admin
```

## App path available today

Login → operator → identify machine → detail/slots → start replenishment →
product lookup → add line. **Complete via HTTP** until Commit 13.

## Diagnostics

| Symptom | Likely cause |
| --- | --- |
| Immediate network failure | cleartext blocked / not a debug build |
| Connection refused | wrong host (`localhost` on device) or port |
| 404 on all routes | `/api/v1` duplicated in `API_BASE_URL` |
| Google login never hits backend | Android OAuth client / SHA-1 mismatch |
| `503` on `/auth/session` | backend Google env missing |
| `403` after login | operator or grants not seeded for that `sub` |
| Exception starting replenishment | `APP_ENV=production` |
