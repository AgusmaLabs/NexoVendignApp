# VendingApp Authentication

## Current flow (Commit 3)

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

`Authenticated` means Google produced an `id_token` in memory. It does **not**
mean VendingApp holds a NexoVending session JWT.

## Not implemented yet (Commit 4)

```text
id_token
   ↓
POST /api/v1/auth/session
   ↓
Session JWT
   ↓
SecureStorage
```

## Architecture

* `GoogleSignInService` isolates the official `google_sign_in` SDK.
* `AuthenticationController` owns UI state:
  `Unauthenticated` → `Authenticating` → `Authenticated` / `AuthenticationFailure`.
* Cancellation returns to `Unauthenticated` (not treated as an unexpected error).
* UI never displays the `id_token`.

## Configuration

Client IDs are supplied at build time (never committed):

```bash
flutter run \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=your-web-client-id.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=your-ios-client-id.apps.googleusercontent.com
```

| Define | Purpose |
| ------ | ------- |
| `GOOGLE_SERVER_CLIENT_ID` | Web/server OAuth client ID (required for `id_token` on Android) |
| `GOOGLE_IOS_CLIENT_ID` | iOS OAuth client ID |

### Android

1. Register the Android app package (`com.example.vendingapp` until renamed) in Google Cloud / Firebase.
2. Add the SHA-1 of each signing keystore used for debug/release.
3. Create a **Web** OAuth client and pass it as `GOOGLE_SERVER_CLIENT_ID`.
4. Do **not** commit `google-services.json` if you use Firebase downloadables.

`INTERNET` permission is declared in `android/app/src/main/AndroidManifest.xml`.

### iOS

1. Register the iOS bundle ID in Google Cloud / Firebase.
2. Pass the iOS client ID as `GOOGLE_IOS_CLIENT_ID` (Dart initialization).
3. Replace `com.googleusercontent.apps.REPLACE_ME` in `ios/Runner/Info.plist`
   (`CFBundleURLSchemes`) with the real `REVERSED_CLIENT_ID`.
4. Do **not** commit `GoogleService-Info.plist`.

## Security

* Never log `id_token`, access tokens, or authorization headers.
* Commit 3 keeps the Google `id_token` in memory only.
* Do not write the Google `id_token` to `LocalStorage` or `SecureStorage`.
* Secure storage is reserved for the NexoVending Session JWT in Commit 4.

## Testing

Automated tests use `FakeGoogleSignInService`. They never call real Google
accounts or NexoVending.

```bash
flutter test
```

## Related

* [ADR-002: Google Sign-In Boundary](adr/ADR-002-google-sign-in-boundary.md)
* [Networking](NETWORKING.md)
* [Architecture](ARCHITECTURE.md)
