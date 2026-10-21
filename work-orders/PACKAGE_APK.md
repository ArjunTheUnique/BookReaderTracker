# WORK ORDER — PACKAGE-APK: make the repo a buildable project

**Version Stamp: v1.0** · 2026-10-21 · Project: Reading Tracker ("Shelf")

## Why
The operator wants the installable app built on **GitHub Actions** (free, no machine of theirs). The build workflow is in place (`.github/workflows/build-apk.yml`). But the repo currently holds **loose artifacts**, not a **buildable Flutter project** — so the workflow has nothing it can compile.

## What to do
Commit your **complete working Flutter project** to the repository root, so that `flutter build apk` succeeds there. At minimum:

1. **`pubspec.yaml`** at the repo root — the exact pinned manifest (name `shelf_app`, Flutter 3.47.7, Dart ≥3.10).
2. **`build.yaml`** at the root — the sources config that makes codegen see `src/**` and `tests/**`.
3. **`src/`** — `modules/` and `app/` (already present; keep them).
4. **`tests/`** — already present.
5. **`android/`** — the full platform scaffold from your sandbox (`build.gradle`, `settings.gradle`, `app/`, `gradle/`, `gradle.properties`, `MainActivity`), **with the widget registered**:
   - `android/app/src/main/kotlin/com/example/shelf_app/ShelfWidgetProvider.kt`
   - `android/app/src/main/res/layout/shelf_widget.xml`
   - `android/app/src/main/res/xml/shelf_widget_info.xml`
   - the `<receiver>` block from `android/AndroidManifest_widget_entry.xml` merged into `android/app/src/main/AndroidManifest.xml`
6. Any other file your sandbox project has that the build needs (e.g. `.fvmrc`).

**Entry point:** the app's `main.dart` lives at `src/app/main.dart`, so the workflow builds with `-t src/app/main.dart`. If you prefer a conventional `lib/main.dart` entry, add one that forwards to `src/app/main.dart` and say so — I will point the workflow at it.

## Definition of done
- From a clean checkout of `main`, these succeed **on the GitHub runner**:
  ```
  flutter pub get
  dart run build_runner build --delete-conflicting-outputs
  flutter build apk --release -t src/app/main.dart
  ```
- The workflow run at `.github/workflows/build-apk.yml` is **green**, and its artifact **`shelf-app-apk`** contains `app-release.apk`.
- Write `receipts/PACKAGE-APK_receipt.md` with the run URL and the APK size, comment `DELIVERED PACKAGE-APK` on the task issue, and fire a `repository_dispatch` of type `builder-delivered`.

## Note
Until this is done, the APK workflow will fail — that is expected, not a defect. It goes green the moment the project is complete.
