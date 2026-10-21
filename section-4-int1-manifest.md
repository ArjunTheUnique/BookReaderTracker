# SECTION 4 — PINNED DEPENDENCY MANIFEST

Unchanged — this order adds and removes no dependency.

```yaml
name: shelf_app
description: "Reading Tracker (Shelf) - full stack + INT-1"
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
  pdfx: 2.11.0
  epubx: 4.0.0
  file_picker: 13.1.0
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
