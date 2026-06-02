# AI Agents Context

Authoritative context file for AI agents working on this project. Keep it up to
date when conventions change. Do **not** add per-session activity logs here — git
history is the authoritative record.

This is the iOS sibling of [pathivu-android](https://github.com/aarshps/pathivu-android),
a Hora-family habit tracker. Same Firestore data layer (documents are
interchangeable), different UI runtime. The build/release machinery is a direct
descendant of [varisankya-ios](https://github.com/aarshps/varisankya-ios).

---

## Stack

| Layer | Technology | Notes |
| --- | --- | --- |
| Language | **Swift 5.0 language mode** | NOT Swift 6. `SWIFT_VERSION: "5.0"` + `SWIFT_STRICT_CONCURRENCY: minimal`. Firebase iOS SDK 11.x hasn't completed Sendable migration. |
| UI | SwiftUI, iOS 26+ | Liquid Glass APIs. Deployment target: iOS 26.0. Do not lower it. |
| Backend | Firebase iOS SDK v11.x (SPM) | FirebaseAuth, FirebaseFirestore, FirebaseAnalytics, FirebaseMessaging. |
| Auth | Sign in with Apple + Google Sign-In | **Both mandatory** per App Store Guideline 4.8. |
| State | `@Observable` (Observation framework) | ViewModels injected via `@Environment`. Not `ObservableObject`. |
| Project gen | XcodeGen | `project.yml` → `Pathivu.xcodeproj` (gitignored, never hand-edit). |
| CI | GitHub Actions `macos-latest` + Xcode latest-stable | No local Mac required for CI; validation = "CI is green" (no Xcode on Windows). |

---

## Firebase

| Item | Value |
| --- | --- |
| Firebase project | `hora-pathivu` (project number `957084965409`) — **shared with Android** |
| iOS bundle ID | `com.hora.pathivu` |
| iOS app registration | **TODO** — no iOS app registered in `hora-pathivu` yet. Register it, download `GoogleService-Info.plist`, set `GOOGLE_SERVICE_INFO_BASE64` secret, and replace the placeholder `GOOGLE_SIGN_IN_URL_SCHEME` in `project.yml` with the plist's `REVERSED_CLIENT_ID`. |
| GoogleService-Info.plist | gitignored; CI base64-decodes it from `GOOGLE_SERVICE_INFO_BASE64`. |

---

## Core mandates

1. **Never commit secrets.** `GoogleService-Info.plist`, `*.p12`, `*.cer`,
   `*.mobileprovision`, App Store Connect `.p8` keys are all gitignored.
2. **Never hand-edit `Pathivu.xcodeproj`.** Edit `project.yml`; XcodeGen regenerates.
3. **Validate via CI.** Push and watch `iOS Build (unsigned)`. No local Xcode on Windows.
4. **Keep Firestore document shapes identical to Android.** Field names, types,
   and the `completedDates` array layout must match `pathivu-android` exactly.
5. **Do not lower the iOS deployment target.** Liquid Glass is iOS 26-only.
6. **Both Sign in with Apple AND Google Sign-In are required** (Guideline 4.8).
7. **Account deletion is mandatory** (Guideline 5.1.1(v)) — wired through
   `SettingsView` → "Delete account" → `AuthService.deleteAccount()`. Don't remove it.

---

## Firestore data model (identical to Android)

```
users/{uid}/habits/{habitId}        Habit document
  .name: String
  .emoji: String              icon KEY (not an emoji), e.g. "water" — see AppConstants
  .colorIndex: Int            legacy, unused
  .category: String           legacy
  .scheduleType: String       "daily" | "weekly" | "weekly_count" | "monthly_count"
  .daysOfWeek: [Int]          ISO 1=Mon … 7=Sun (for "weekly")
  .weeklyTarget: Int          for "weekly_count"
  .monthlyTarget: Int         for "monthly_count"
  .negative: Bool             a "quit" habit; marking it logs a slip
  .completedDates: [String]   ISO yyyy-MM-dd; toggled via arrayUnion/arrayRemove
  .createdAt: Timestamp       serverTimestamp on create
  .sortOrder: Int             drag order; new habits = creation millis (bottom)
  .archived: Bool             soft-delete; history kept
```

All streak / rate / heatmap math is in `Models/HabitStats.swift` — a faithful port
of `util/HabitStats.kt`. Two settings feed it as static config: `dayStartHour`
(new-day offset) and `weekStartDay`; `Preferences.syncStatsConfig()` pushes them in.

---

## Key files

| Path | Purpose |
| --- | --- |
| `project.yml` | XcodeGen spec; single source of truth for build settings + deps |
| `Pathivu/App/PathivuApp.swift` | App entry; Firebase init; `.onOpenURL` for Google Sign-In |
| `Pathivu/App/RootView.swift` | Switcher: App Lock gate / SignInView / MainView |
| `Pathivu/Models/Habit.swift` | Codable + `@DocumentID` + `@ServerTimestamp`; schedule constants |
| `Pathivu/Models/HabitStats.swift` | Pure analytics (streaks, week-row, heatmap, schedule labels) |
| `Pathivu/Services/AuthService.swift` | `@MainActor` singleton; Apple + Google sign-in |
| `Pathivu/Services/FirestoreService.swift` | Observe habits; toggle; reorder; archive/restore/delete |
| `Pathivu/Services/NotificationScheduler.swift` | Single daily local reminder; reschedule on foreground |
| `Pathivu/Services/Preferences.swift` | `@Observable`; UserDefaults; pushes day-start/week-start into HabitStats |
| `Pathivu/ViewModels/MainViewModel.swift` | Observe + derive `HeroState`; toggle/reorder/archive |
| `Pathivu/Views/MainView.swift` | Hero ring + reorderable habit list + FAB + toolbar |
| `Pathivu/Views/AddHabitSheet.swift` | Create/edit: name, Build/Quit, icon picker, schedule |
| `Pathivu/Views/DayEditorSheet.swift` | Back-fill any past day (own Firestore listener) |
| `Pathivu/Views/StatsView.swift` | Tiles + 16-week heatmap + per-habit breakdown |
| `Pathivu/Views/SettingsView.swift` | Appearance, reminders, tracking, archived, account |
| `.github/workflows/ios-build.yml` | Unsigned device build; every push |
| `.github/workflows/ios-release.yml` | Signed archive + TestFlight; manual / `v*` tag |

---

## Known compiler pitfalls (from the Varisankya iOS sibling)

| Symptom | Fix |
| --- | --- |
| "stored property of 'Sendable'-conforming struct has non-Sendable type" | Don't add `Sendable`/`Hashable` to models with `@DocumentID`/`@ServerTimestamp`; keep `SWIFT_STRICT_CONCURRENCY: minimal`. |
| "main actor-isolated property can not be referenced from a nonisolated context" (deinit) | Singletons: remove `deinit`. |
| "'init()' deprecated in iOS 26.0: Use init(windowScene:)" | Use scene-based `UIWindow`; see `AuthService.presentationAnchor`. |
| `minVersion:` rejected by XcodeGen | Use `from:` (up-to-next-major) in `packages:`. |

---

## GitHub Secrets required for release (9 total)

`GOOGLE_SERVICE_INFO_BASE64`, `APPLE_TEAM_ID`, `APPLE_API_ISSUER_ID`,
`APPLE_API_KEY_ID`, `APPLE_API_KEY_BASE64`, `BUILD_CERTIFICATE_BASE64`,
`P12_PASSWORD`, `PROVISIONING_PROFILE_BASE64`, `KEYCHAIN_PASSWORD`.

Run `./scripts/check_apple_secrets.sh` to audit. The signing-asset helpers
(`generate_csr.sh`, `pack_p12.sh`) need no Mac.

---

## Operational workflow

- **Plan → Act → Validate.** Validation = CI green (no Xcode/Simulator on Windows).
- Commit/push only when asked. End commit bodies with
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
