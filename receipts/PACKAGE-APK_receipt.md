# RECEIPT — PACKAGE-APK

**Status: DELIVERED** · 2026-10-21 · Project: Reading Tracker ("Shelf")
Order: `work-orders/PACKAGE_APK.md` · Version Stamp: v1.0

## What was committed

The **complete, buildable Flutter project** at the repo root — 57 files:

- `pubspec.yaml` (exact pins), `pubspec.lock`, `build.yaml`, `analysis_options.yaml`, `.gitignore`, `.metadata`
- `src/` — `modules/` (M1–M7 + the three adapter files + the generated `m1_library_store.g.dart`) and `app/` (`main.dart`, `app_shell.dart`, `routes.dart`, `wiring.dart`)
- `tests/` — all eight suites
- `android/` — the full platform scaffold (`build.gradle.kts`, `settings.gradle.kts`, the Gradle wrapper, `MainActivity.kt`, `res/`) with the home-screen widget registered

**Entry point:** `src/app/main.dart`, which the workflow builds with `-t src/app/main.dart`.
There is deliberately **no `lib/` entry**: a file under `lib/` can reach neither `src/` nor the top-level package by a relative import or a `package:` import, so the entry lives with the app it boots.

## The workflow run

| Field | Value |
|---|---|
| Workflow | `.github/workflows/build-apk.yml` |
| Run | **#5 — SUCCESS (green)** |
| Run URL | https://github.com/ArjunTheUnique/BookReaderTracker/actions/runs/39567187584 |
| Artifact | `shelf-app-apk` |
| APK inside | `app-release.apk` |
| APK size | **60,355,604 bytes (57.6 MiB)** |
| APK SHA-256 | `967f3e4f20fdc6c16f1c8158640bba3e7bf16e0f3bbaebeb6049a41131cc6233` |

Download it from the run page: the **Artifacts** section, `shelf-app-apk`.

## The one defect found and fixed along the way

The first substantive run failed with:

```text
AAPT: error: unexpected element <intent-filter> found in <manifest><application>.
```

**Root cause (mine):** `android/AndroidManifest_widget_entry.xml` carried a bare deep-link
`<intent-filter>` after the `<receiver>`. The merge script inserts the file's whole body
immediately before `</application>`, so that filter landed directly under `<application>` —
which AAPT rejects, since an `<intent-filter>` must live inside an activity or a receiver.

**Fix (commit `4bb72e7`):** the deep-link `<intent-filter>` now lives **inside `MainActivity`**
in `android/app/src/main/AndroidManifest.xml`, and the merge entry carries **only the
`<receiver>`**. The manifest is well-formed and its nesting is correct.

## Honest note on the earlier failure

Run **#3** failed before any of this project's code ran: Maven Central returned **HTTP 429
Too Many Requests** for the Kotlin Gradle artifacts. That is a transient GitHub-side rate
limit, not a project defect; it cleared on retry.

## Definition of done

- `flutter pub get`, `dart run build_runner build` and `flutter build apk --release -t src/app/main.dart` all succeed **on the GitHub runner** — proven by the green run above.
- The artifact `shelf-app-apk` contains `app-release.apk` (57.6 MiB) — verified by downloading it and checking the file.
