# WORK-ORDER BUILD REQUIREMENTS (shared preamble)
Applies to every module work order, M2 onward. Version 1.0 · 2026-10-19
Read this *with* each module's work order. It carries the findings from M1's build so no later module rediscovers them.

---

## 1. Toolchain (mandatory — ADR-011)

| Thing | Value |
|---|---|
| Flutter | **3.47.7** (stable) |
| Dart | **3.13.5** (bundled with Flutter 3.47.7) |
| Codegen before test | `dart run build_runner build` **must run before** `flutter test` |
| Host SQLite (Windows) | a `sqlite3.dll` must be available to the test runner |

If the toolchain is missing, the builder returns the package as **INCOMPLETE** — never a fabricated PASS.

## 2. Project shape

| Item | Value |
|---|---|
| Project name | **`shelf_app`** — never `shelf` (it clashes with a published library that `build_runner` depends on) |
| Module folder | `src/modules/` |
| Test folder | `tests/` |
| Import style | modules import each other by relative path within `src/modules/` |

## 3. `build.yaml` is mandatory (ADR — see Master Doc folder tree note)

Dart's build tooling scans only `lib/`, `test/`, `bin/`, `web/` by default. Because modules live in `src/`, **drift's generator silently writes ZERO outputs** unless `build.yaml` widens the source set. It must be committed:

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

Symptom if missing: `build_runner` reports success but writes 0 outputs, and the module then fails to compile with `part '....g.dart' not found`.

## 4. Corrected, verified pins (ADR-010)

| Package | Pin | Note |
|---|---|---|
| `drift` | `2.35.2` | exists |
| `drift_dev` | `2.35.1` | **not** 2.35.2 — that is not published |
| `sqlite3_flutter_libs` | `0.5.42` | **deliberate** — `0.6.0+eol` is a retired no-op that bundles no SQLite engine |
| `path_provider` | `2.1.6` | |
| `build_runner` | `2.16.2` | **not** 2.17.1 |

**Rule:** verify every pin exists as published for that exact package before it enters an order. Never infer a companion's version from its parent.

## 5. Dart correctness rules (learned by compiling M1 — ADR-012)

These three caused real compile failures and could not be seen without compiling:

1. **`part '....g.dart';` must come AFTER all `import` directives** in a Dart library. Putting it above the imports is invalid Dart.
2. **Narrow nullable payload fields to `String?` before use.** A value typed `Object?` cannot be used as `.isEmpty`; cast explicitly (e.g. `Value<String?>(filePath)`).
3. **Match the real drift return type.** `customSelect(...).getSingle()` returns `QueryRow`, not `TypedResult`.

## 6. What still counts as "done"

A module is not done until: it **compiles**, its 5-part suite **runs on Flutter 3.47.7** and passes, the manifest is fully pinned from `pubspec.lock`, and the receipt is the **verbatim `flutter test` output**. A rules-only harness may corroborate; it never satisfies the gate.
