# ejioji — Flutter front end

Dark only. Feature-first. No backend yet — every network call is a marked
`TODO(backend)` next to the endpoint it will use.

```bash
flutter pub get
cp config/dev.example.json config/dev.json      # then set API_BASE_URL
flutter run --dart-define-from-file=config/dev.json
```

`flutter analyze` is clean. Treat it as a gate: nothing merges with an issue.

---

## How it is laid out

```
lib/
  main.dart                 boot: config check, orientation, ProviderScope
  app/
    app.dart                MaterialApp.router, dark theme, text-scale clamp
    router.dart             every route, and the ONLY auth guard
    routes.dart             every path as a constant
    shell.dart              the three tabs
  core/
    config/env.dart         --dart-define only; no secrets in the repo
    network/                api_client, endpoints, one error type
    session/session.dart    who is signed in, verified, premium, paused
    storage/token_store.dart  Keychain / EncryptedSharedPrefs
    theme/                  tokens, typography, platform, app_theme
  shared/
    widgets/                the design system — everything screens are built from
    mock/demo_data.dart     placeholder content; delete when the API lands
  features/
    <feature>/presentation/ one file per screen
```

**The rule:** a screen may import `shared/` and its own feature. It may not
import another feature. If two features need the same widget, it moves to
`shared/widgets`.

**The design system is not optional.** No screen writes a hex colour, a font
family or a raw `TextStyle`. Those live in `core/theme/tokens.dart` and
`typography.dart`, and everything else composes the widgets in
`shared/widgets`. That is what makes a colour change one commit rather than
forty.

---

## The two platform differences

Exactly two, both in `core/theme/platform.dart`:

| | iOS | Android |
|---|---|---|
| Typeface | SF Pro (system) | **Google Sans**, falling back to Roboto |
| Tab bar | **Floats** — glass, inset 16, content scrolls under | **Docked** — opaque, on the bottom edge, no glass |

Everything else is identical. A new `if (isAndroid)` needs a better reason than
"that is how Android does it".

**Google Sans is licensed and is not checked in.** The app asks for it by name
and falls back to Roboto when it is absent, which is correct on a stock device.
If your build has a licensed copy, drop the files into `assets/fonts/` and
uncomment the `fonts:` block in `pubspec.yaml`.

---

## Security

- **Tokens** live in the Keychain (iOS) and EncryptedSharedPreferences
  (Android), never in `SharedPreferences`. `first_unlock_this_device` means
  they survive a reboot but do not sync to iCloud or another device.
- **No secrets in the repository.** The client holds a base URL and nothing
  else. Every privileged call is authorised by a token the backend issued.
  `config/*.json` is gitignored.
- **Certificate pinning** is required in prod builds (`CERT_PINS`), enforced by
  `Env.assertValid()` at boot.
- **Logs never contain headers or bodies**, and are debug-only. A request log
  with an `Authorization` header in it is a leaked credential.
- **Errors never leak internals.** `ApiException.message` is written for a
  person; 5xx bodies are never shown, because they can carry a stack trace.
- **One refresh, shared.** Concurrent 401s wait on a single refresh rather than
  racing and invalidating each other.
- **Input is bounded** — the composer caps at 2000 characters so a paste cannot
  push an unbounded payload at the API.
- **DigiLocker opens in an external browser, never a WebView.** A WebView we
  control must never see a government login.
- **Entitlement is server-side.** The client never grants itself Premium from a
  local receipt.

---

## Push notifications

Three of them, all sent by the backend: a chat message, a chat request, and a
request accepted. The app asks for permission once somebody is signed in, and
tells the server its token then and on every rotation. What was written never
travels: a push carries a first name, a fixed line of copy, and ids.

They need a Firebase project, and its public client values go in
`config/dev.json` next to the base URL:

```
"FCM_PROJECT_ID", "FCM_SENDER_ID",
"FCM_ANDROID_APP_ID", "FCM_ANDROID_API_KEY",
"FCM_IOS_APP_ID", "FCM_IOS_API_KEY"
```

The project and the sender are project-wide; the app id and the key are per
platform, because Firebase registers a phone app once per platform. The Android
pair is in `google-services.json` and the iOS pair in `GoogleService-Info.plist`
(both gitignored, and neither is read by the build: they are where these values
are copied from).

None of them is a secret; every Android app ships them in plain sight. What
actually sends a push is a service-account key, and that lives on the server.
They are defines rather than checked-in console files so that a build without a
Firebase project still builds and runs, with push simply off. That is also why
the web build never touches Firebase.

`core/push/push.dart` is the only file that knows Firebase exists.

## What is wired, and what is not

Built and navigable: sign-in (number, OTP), onboarding (basics, connect,
reading, category picking), the profile in all three readings, home with
filters, notifications and both empty feeds, chats and a conversation with the
friends-and-family handshake, verification hub, edit info, edit insights (the
accounts page and the tiles behind it), account, settings and its four
sub-pages, premium, and take a break.

Also built: the DigiLocker steps and handoff, the selfie check's three capture
steps, both verification results and the shared error screen, "Why this
matters", the report flow's three screens, the shared friends and family pages,
and arrange mode with drag-to-reorder and remove.

**Every screen from the mocks now has a Dart file.**

**Every network call is a stub.** Search `TODO(backend)` for the complete list;
each one names the endpoint in `core/network/endpoints.dart` it will call.
`shared/mock/demo_data.dart` supplies the placeholder content, and nothing
outside `presentation` imports it — when that file deletes cleanly, the backend
is fully wired.
