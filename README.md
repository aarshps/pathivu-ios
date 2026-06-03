# Pathivu for iOS

iOS sibling of the [Pathivu Android](https://github.com/aarshps/pathivu-android) habit
tracker. SwiftUI, iOS 26+ Liquid Glass, Firebase Auth + Firestore, Sign in with Apple +
Google Sign-In. Same Firebase project (`hora-pathivu`), same Firestore documents — sign in
on either platform and see the same habits, streaks and check-offs.

There's also a **web app** — **[pathivu-web.vercel.app](https://pathivu-web.vercel.app)**
([repo](https://github.com/aarshps/pathivu-web), Next.js on Vercel) — talking to the same
`hora-pathivu` Firestore, so habits sync live across Android, iOS, and web. It shipped first
so users have something to use while this App Store release is pending.

**Pathivu** (Malayalam *പതിവ്* — "habit / routine") lets you build good habits, quit bad
ones, and watch your streaks grow.

## Status

| Surface | State |
| --- | --- |
| Source code | All screens ported to SwiftUI / iOS 26 Liquid Glass |
| CI | `iOS Build (unsigned)` runs on every push |
| Firebase | iOS app **pending registration** in `hora-pathivu` (place real `GoogleService-Info.plist` + reversed client id before sign-in works) |
| App Store | Pending Apple Developer Program enrollment |

## What this repo contains

| Path | Purpose |
| --- | --- |
| `project.yml` | XcodeGen spec — `.xcodeproj` is generated on the build machine, not stored in git |
| `Pathivu/App/` | App entry point, root view, `UIApplicationDelegate` for Firebase init |
| `Pathivu/Models/` | `Habit`, `HabitStats` (pure analytics), `HeroState`, icon/constants |
| `Pathivu/Services/` | `AuthService`, `FirestoreService`, `NotificationScheduler`, `Preferences`, `Analytics`, `Haptics`, `BiometricAuth` |
| `Pathivu/ViewModels/` | `MainViewModel` (`@Observable`) |
| `Pathivu/Views/` | SwiftUI screens with Liquid Glass treatment |
| `Pathivu/Resources/` | `Info.plist`, asset catalog, entitlements |
| `scripts/` | placeholder icon generator + Apple signing helpers (no Mac required) |
| `.github/workflows/` | CI: unsigned build on every push; signed TestFlight release on manual dispatch |

## Build locally (macOS only)

```bash
brew install xcodegen
xcodegen generate
open Pathivu.xcodeproj
```

Place a real `GoogleService-Info.plist` in `Pathivu/Resources/` (download it after
registering an iOS app in the `hora-pathivu` Firebase project) before sign-in and Firestore
will work, and update `GOOGLE_SIGN_IN_URL_SCHEME` in `project.yml` to that plist's
`REVERSED_CLIENT_ID`.

## Parity with Android

The Firestore document layout is **identical** so a single user can sign in on both
platforms and see the same data:

- `users/{uid}/habits/{habitId}` — one flat document per habit
- completions stored as `completedDates: [String]` (ISO `yyyy-MM-dd`), toggled atomically
  with `arrayUnion` / `arrayRemove`

All streak / rate / heatmap math lives in `HabitStats.swift`, a 1:1 port of Android's
`util/HabitStats.kt` — the single source of truth. The schedule encodings
(`daily` / `weekly` / `weekly_count` / `monthly_count`), the `negative` quit-habit flag, and
the `emoji` icon-key field all match Android exactly.

Notification scheduling differs by platform: Android runs a chained WorkManager worker; iOS
schedules a single local `UNUserNotificationCenter` reminder, rescheduled every time the app
foregrounds or habits change. See `Services/NotificationScheduler.swift` for the rationale.

## Design language

- Targets iOS 26+ exclusively so the **Liquid Glass** APIs are available: `.glassEffect(in:)`,
  `GlassEffectContainer`, `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)`.
- The hero "today" ring, habit cards, the heatmap and every sheet sit on translucent glass
  over a soft green-tinted backdrop.
- Haptics mirror the Android M3 expressive scheme (`tick`, `click`, `success`, `warning`,
  `error`) — see `Services/Haptics.swift`.

## Bundle ID + Firebase

- iOS bundle ID: `com.hora.pathivu`
- Firebase project: `hora-pathivu` (the same one the Android app uses — both share Auth and
  Firestore). Register an **iOS app** there, download its `GoogleService-Info.plist`, and add
  it locally (gitignored). CI reads it from the `GOOGLE_SERVICE_INFO_BASE64` GitHub Secret.

## License

MIT.
