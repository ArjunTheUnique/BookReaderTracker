# INT-2 — Native Widget & Packaging: Build Report (Android only)

Order: INT-2 v1.0 · Date 2026-10-20 · Platform: **Android only** (iOS dropped per the
operator's directive; INT-2 section 4 had already recommended shipping Android first).

## 1. The build command and its output

Command run in the builder sandbox:

```
flutter build apk --release
```

Verbatim output:

```text
[!] No Android SDK found. Try setting the ANDROID_HOME environment variable.
```

**The APK was NOT built, and no APK file is delivered.** Stated plainly, per ADR-012:
the builder sandbox has **no Java, no Android SDK and no Gradle**, and only 2 GB of RAM
(a Gradle/AGP build would very likely run out of memory even with the SDK present). The
Android platform folder was scaffolded (`flutter create --platforms=android`) and the
widget sources were placed, but the toolchain to compile them is not available here.

## 2. The produced APK file

**None.** See section 1.

## 3. The native widget source files (delivered)

| File | Destination in the project |
|---|---|
| `ShelfWidgetProvider.kt` | `android/app/src/main/kotlin/com/example/shelf_app/ShelfWidgetProvider.kt` |
| `shelf_widget.xml` | `android/app/src/main/res/layout/shelf_widget.xml` |
| `shelf_widget_info.xml` | `android/app/src/main/res/xml/shelf_widget_info.xml` |
| `AndroidManifest_widget_entry.xml` | the `<receiver>` block to paste into `android/app/src/main/AndroidManifest.xml` |

The widget reads the shared store M5 wrote (key `shelf_payload`), shows
`pages today / goal` plus a progress bar, and falls back to "—" + "no data" when the store
has no fresh payload (staleness guard S6). It shows numbers only; titles stay off unless
`WIDGET_SHOW_TITLES` is enabled (privacy T7). Tapping it opens the app via the
`shelf://…` route M5 minted (C6).

## 4. What was verified on-device

**Nothing on-device** — the builder has no Android device or emulator. INT-2's V2 (widget
renders) and V3 (tap opens the app) remain **unverified** and must be run by the operator
on a real device or emulator.

What WAS verified here:

- **V4 — the M5 suite still passes: 5/5** (no regression). See the INT-1 receipt.
- The Kotlin and XML sources are delivered and internally consistent with M5's payload key
  and route format, but they have **not been compiled** (no Android toolchain).

## 5. To finish INT-2 (operator, on a machine with the Android SDK)

```
flutter pub get
dart run build_runner build
flutter build apk --release
```

Then install the APK on a device, add the widget to the home screen, and confirm V2 and V3.

## Honest summary

INT-2's **sources are complete**; its **build and on-device verification are not** — they
need an Android SDK, which this sandbox does not have. No build output has been invented.
