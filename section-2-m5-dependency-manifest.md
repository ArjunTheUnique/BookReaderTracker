# SECTION 2 — PINNED DEPENDENCY MANIFEST

Every dependency pinned to an exact version, verified against the registry as published
(ADR-010). `home_widget` appears ONLY in the adapter file, never in the module or its test.

| Layer | Package | Pin |
|---|---|---|
| SDK | Flutter | 3.47.7 (stable) |
| Language | Dart | 3.13.5 (bundled) |
| Widget plugin (edge only) | home_widget | 0.10.0 |
| Storage (via M4/M1) | drift | 2.35.2 |
| Storage codegen | drift_dev | 2.35.1 |
| Native sqlite | sqlite3_flutter_libs | 0.5.42 |
| Paths | path_provider | 2.1.6 |
| Codegen runner | build_runner | 2.16.2 |
| Test | flutter_test | from the Flutter SDK |

pubspec.yaml (exact pins):

```yaml
name: shelf_app
description: "Reading Tracker (Shelf) - M1, M4, M5, M6, M7"
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
  home_widget: 0.10.0
  cryptography: 2.9.0
  cryptography_flutter: 2.3.4

dev_dependencies:
  flutter_test:
    sdk: flutter
  drift_dev: 2.35.1
  build_runner: 2.16.2

flutter:
  uses-material-design: true
```

`build.yaml` (mandatory — modules live in `src/`):

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