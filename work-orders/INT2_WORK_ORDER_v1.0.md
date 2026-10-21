# INTEGRATION WORK ORDER — INT-2: Native Widget Shells & Packaging
**Order revision: v1.0**  ·  Date 2026-10-20  ·  Project: Reading Tracker ("Shelf")
Fully self-contained. The Stack Builder Agent sees only this document.

> Track note: INT-2 pairs with INT-1. INT-1 makes the app run; INT-2 gives it the home-screen widget and turns it into an installable file.

---

## 0. Build prerequisites (unchanged)
Flutter **3.47.7** · Dart **3.13.5** · project name **`shelf_app`** · `build.yaml` mandatory · real build output only.

---

## 1. Identity

| Field | Value |
|---|---|
| Order ID | INT-2 |
| Version Stamp | v1.0 |
| Deliverables | Android widget shell · iOS widget shell · the `home_widget` registration · the packaged app file |
| One-line purpose | Draw the daily-target widget on the phone's home screen, wire it to M5's payload, and build the installable app. |

---

## 2. The native widget (the feature the user asked for)

The widget is **written natively** — `home_widget` provides the bridge, not the UI.

| Platform | Where | What |
|---|---|---|
| Android | `android/app/src/main/kotlin/.../ShelfWidgetProvider.kt` + `res/layout/shelf_widget.xml` + `AndroidManifest.xml` entry | an AppWidget that reads the shared store and shows the daily target |
| iOS | `ios/ShelfWidget/…` (SwiftUI + WidgetKit) + app-group entitlement | a WidgetKit widget reading the same shared store |

**What the widget shows (default):** the day's numbers only — `pages today / goal` (e.g. "34 / 40") plus a small progress bar. **Book titles are OFF by default** (privacy, T7); they appear only if `WIDGET_SHOW_TITLES` is enabled.

**Staleness (S6):** if the shared store has no fresh payload, show "—" and a last-updated time — never a wrong number.

**Tap (C6):** tapping the widget opens the app via the deep-link route M5 produced (`shelf://…`).

---

## 3. Wiring to M5

INT-1's composition root pushes the payload through M5 → `WidgetHost` (the `home_widget` adapter) → the shared app-group store. The native widget reads that store on the OS's own refresh schedule. The widget never computes anything; it only displays what M5 pushed.

---

## 4. Packaging — and one honest constraint

| Target | Command | Where it can be built |
|---|---|---|
| Android APK (sideload) | `flutter build apk --release` | anywhere, including a Linux sandbox |
| Android App Bundle (Play Store) | `flutter build appbundle --release` | anywhere |
| iOS (.ipa) | `flutter build ipa` | **requires macOS + an Apple Developer account** |

**The constraint, stated plainly:** an iOS build needs a **Mac** and a **paid Apple Developer account (~$99/yr)** for anything beyond a local 7-day sideload. That sits against the project's **₹0 budget** and the operator's **zero-local-work** rule. 

**Recommendation (Architect's ruling):** **ship Android first.** Build and deliver a signed **APK** now; defer iOS until a Mac or a cloud macOS runner and an Apple account are available. Do not block the Android app on the iOS toolchain.

---

## 5. Failure & security guards

- **Permission fallback (S7):** a refused notification/widget permission must not crash the app; the app works without the widget.
- **Privacy (T7):** numbers only by default; no book titles on the lock screen unless enabled.
- **No secrets:** the widget contains no credentials; the app-group identifier is config, not a secret.
- **Config variables:** `WIDGET_REFRESH_MIN`, `WIDGET_SHOW_TITLES`.

---

## 6. Verification & Definition of Done

- **V1 — Android build succeeds:** `flutter build apk --release` completes and produces an APK.
- **V2 — Widget renders:** on an Android device/emulator, the widget appears and shows the pushed numbers; a stale store shows "—".
- **V3 — Tap opens the app:** tapping the widget lands on the right screen (from INT-1's routes).
- **V4 — The M5 suite still passes** (no regression): `flutter test tests/test_m5_widget_bridge.dart`.

**Definition of Done:** the Android APK builds and installs; the widget shows the daily target and opens the app on tap; no regression in M5. iOS is explicitly **out of scope for this order** (deferred per §4).

**Return format:** a short package — (1) the build command and its output; (2) the produced APK file; (3) the native widget source files; (4) a note on what was verified on-device.

---

## 7. Passport header

```
# ============================================================
# INTEGRATION PASSPORT — INT-2 Native Widget & Packaging
# Version Stamp : v1.0
# Files: android/app/src/main/kotlin/.../ShelfWidgetProvider.kt
#        android/app/src/main/res/layout/shelf_widget.xml
#        ios/ShelfWidget/...  (deferred)
# ------------------------------------------------------------
# SAFE TO EDIT  : widget layout, colours, refresh interval
# DO NOT TOUCH  : the shared-store key names (M5 writes them),
#                 the deep-link route format, and the privacy
#                 default (numbers only unless titles enabled)
# ============================================================
```
