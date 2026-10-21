# SECTION 2 — PINNED DEPENDENCY MANIFEST

Every dependency pinned to an exact version. Every pin was verified against the registry
as published for that exact package (ADR-010) before it was written here.

| Layer | Package | Pin | Note |
|---|---|---|---|
| SDK | Flutter | 3.47.7 | stable |
| Language | Dart | 3.13.5 | bundled with Flutter 3.47.7 |
| Storage (via M1) | drift | 2.35.2 | exists |
| Storage codegen | drift_dev | 2.35.1 | 2.35.2 is not published |
| Native sqlite | sqlite3_flutter_libs | 0.5.42 | deliberate pin (ADR-013) |
| Paths | path_provider | 2.1.6 | |
| PDF parsing | pdfx | 2.11.0 | Flutter plugin — see finding F1 |
| EPUB parsing | epubx | 4.0.0 | pure Dart |
| Codegen runner | build_runner | 2.16.2 | |
| File picking | file_picker | 13.1.0 | VERIFIED published (latest stable) |
| Test | flutter_test | from the Flutter SDK | |

pubspec.yaml (exact pins):

```yaml
name: shelf_app
description: "Reading Tracker (Shelf) - M1 Library Store + M2 Book Intake."
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

dev_dependencies:
  flutter_test:
    sdk: flutter
  drift_dev: 2.35.1
  build_runner: 2.16.2

flutter:
  uses-material-design: true
```

`build.yaml` (unchanged from M1; still mandatory — modules live in `src/`):

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
