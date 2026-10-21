# SECTION 2 — PINNED DEPENDENCY MANIFEST

STATUS: COMPLETE — every dependency pinned to an exact version, read from the real
`pubspec.lock`, and re-verified after the ADR-013 pin correction.

| Package | Pinned version | Note |
|---|---|---|
| drift | 2.35.2 | exists — confirmed against the registry |
| drift_dev | 2.35.1 | the order asked 2.35.2, which is NOT published |
| sqlite3_flutter_libs | 0.5.42 | DELIBERATE pin per ADR-013 — `0.6.0+eol` is a retired no-op |
| path_provider | 2.1.6 | |
| build_runner | 2.16.2 | the order asked 2.17.1 earlier, which was wrong |

pubspec.yaml (exact pins):

```yaml
name: shelf_app
description: "Reading Tracker (Shelf) - M1 Library Store module."
publish_to: 'none'
version: 0.1.0

environment:
  sdk: ">=3.10.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  drift: 2.35.2
  sqlite3_flutter_libs: 0.5.42
  path_provider: 2.1.6

dev_dependencies:
  flutter_test:
    sdk: flutter
  drift_dev: 2.35.1
  build_runner: 2.16.2

flutter:
  uses-material-design: true
```

## ADR-013 correction applied and re-verified

The manifest previously pinned `sqlite3_flutter_libs: 0.6.0+eol`, a retired, code-removed
release that bundles no SQLite library. It is now pinned to **0.5.42** (the last working
version), as ADR-013 requires. `flutter pub get` reports
`sqlite3_flutter_libs 0.5.42 (was 0.6.0+eol)`, and the full suite was re-run: **5 / 5 PASS**.
No module code changed, so M1 remains v1.0.2.

## Code-generation requirement

Because the module lives in `src/modules/` — outside the folders build_runner scans by
default (`lib/`, `test/`, ...) — drift's generator silently writes ZERO outputs unless a
`build.yaml` widens the source set. The project must contain this file (now also required
by the Master Doc v1.1 folder-tree note):

```yaml
targets:
  $default:
    sources:
      - "$package$"
      - "lib/**"
      - "src/**"
      - "tests/**"
      - "test/**"
      - "bin/**"
      - "web/**"
```

## Independent pin check (ADR-010)

Every pinned version in the Master Doc v1.1 stack was checked against the registry and
confirmed to exist: drift 2.35.2, drift_dev 2.35.1, sqlite3_flutter_libs 0.5.42,
path_provider 2.1.6, build_runner 2.16.2, pdfx 2.11.0, epubx 4.0.0, home_widget 0.10.0,
cryptography 2.9.0, cryptography_flutter 2.3.4. All present.
