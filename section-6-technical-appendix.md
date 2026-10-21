# SECTION 6 — MODULE TECHNICAL APPENDIX

Alphabetical glossary of every technical concept used in the module, for merging into the
Master System Design Document.

| Technical Term / Syntax Used | Plain-English Definition | 1-Sentence Everyday Analogy |
|---|---|---|
| `async` / `await` / `Future` | Marks work that finishes later and pauses a function until it does, without freezing the app. | Ordering a coffee and waiting at the counter rather than blocking the whole queue. |
| Boundary validation | Checking everything a caller hands in, at the door, before any real work starts. | The bouncer checking IDs before anyone gets into the club. |
| Composite primary key | A key made of two columns TOGETHER, so the pair must be unique even when either column alone is not. | A seat is identified by its row AND number, not by the number alone. |
| `const` (compile-time constant) | A value fixed when the app is built and never changed at runtime. | A number engraved on a brass plate rather than written in pencil. |
| Control switch (C1, C2, C5) | A decision or business rule — a yes/no that changes what happens. | The light switch on the wall: it decides, it does not carry the electricity. |
| Data pipe (D1, D2, D4) | The plumbing that stores or moves data, doing no deciding of its own. | The water pipes in a house — they carry water but never choose the temperature. |
| drift | A Dart library that maps Dart classes onto SQLite tables and writes the SQL for you. | A translator who turns your plain sentences into perfect legal wording. |
| `@DriftDatabase` / code generation | An annotation that makes a build step generate a `.g.dart` helper file for your tables. | A printer that stamps out the official forms from your rough template. |
| `build_runner` | The tool that runs drift's code generator and writes the generated file. | The chef's prep cook who chops everything before cooking begins. |
| `build.yaml` (source set) | A config file that tells the code generator which folders to scan. | Telling the scanner which aisles of the warehouse to walk. |
| Enum / fixed value list | A small, closed set of allowed string values. | A form with only two checkboxes, so no one can invent a third answer. |
| Idempotency key | A unique tag on a write so a repeated click or retry can be recognised and ignored. | A numbered claim ticket: hand it in twice, you still get only one coat. |
| In-memory database (`NativeDatabase.memory()`) | A database that lives only in RAM and vanishes when the program ends. | Writing notes on a whiteboard you wipe clean after the meeting. |
| `part` directive | Marks a file whose code is stitched into another file; in Dart it must appear after all imports. | A page inserted into a book after the table of contents, not before it. |
| `PRAGMA integrity_check` | A SQLite command that scans the file and reports whether it is internally consistent. | A doctor's full-body scan that returns "all clear" or flags a problem. |
| `PRAGMA journal_mode=WAL` | A write-ahead logging mode that keeps reads working while a write is in progress. | A scribble pad where you jot a change before committing it to the ledger. |
| `PRAGMA busy_timeout` | How long a query waits for a lock before giving up, in milliseconds. | Waiting politely at a busy door for 5 seconds before walking away. |
| Migration / `MigrationStrategy` | The plan for creating (and later upgrading) the database's tables. | A building's blueprint plus a plan for future extensions. |
| Nullable (`text().nullable()`) | A column or field that is allowed to hold no value. | A form field you may leave blank. |
| `path_provider` | A Flutter plugin that returns safe, app-private folders on the device. | Being handed your own locked locker instead of a shelf in the corridor. |
| Primary key | The column (or columns) that uniquely identify each row in a table. | A passport number that belongs to exactly one person. |
| `QueryRow` / `TypedResult` | Two result types a drift query can return; picking the wrong one is a compile error. | Two kinds of receipt — one plain, one itemised; asking for the wrong one confuses the till. |
| `real` / float | A number that can have a decimal part. | A measuring tape that reads 12.5 cm, not just whole centimetres. |
| Regression guard | A test written to catch a bug that was just fixed, so it cannot quietly return. | A safety catch fitted after a machine bit someone, so it cannot bite again. |
| Retry with backoff | Trying a failed action again, waiting a little longer each time. | Knocking again after a pause when nobody answers the first time. |
| `schema_version` | The number naming which version of the data contract a message speaks. | A form's edition number so both sides know they are on the same revision. |
| Socket contract | The agreed shape of what goes in and what comes back. | A plug and socket that only fit together one correct way. |
| SQLite | A tiny, file-based database that needs no server. | A filing cabinet that lives entirely inside your desk. |
| `String.fromEnvironment` / `int.fromEnvironment` | Reads a value supplied at build time, falling back to a safe default. | A thermostat that uses your set point but defaults to room temperature if unset. |
| Transaction | A group of writes that all succeed together or all fail together. | A bank transfer that either moves the money both ways or not at all. |
| UNIQUE constraint | A database rule forbidding two rows from sharing the same value. | Two people cannot hold tickets with the same seat number. |
| Upsert / `insertOnConflictUpdate` | Insert a row, or update it if it already exists. | "Save" that quietly overwrites the old copy if one is already there. |
| UUID v4 | A random, practically-unique identifier string. | A serial number so long and random it will never clash with another. |
| Zone 1-4 layout | The fixed four-part shape of the file: config, boundary, control, data. | A kitchen divided into pantry, doorway, head chef, and stoves. |

## Patch summary

- **v1.0.1** — Fix C applied: `IdempotencyLedger` primary key is the composite
  `{op, idempotencyKey}`; `_replayIfSeen` matches on `op` AND key.
- **v1.0.2** — three COMPILE fixes found by actually building the module:
  (1) `part` directive moved below the imports; (2) `file_path`/`cover_ref` narrowed to
  `String?`; (3) `_countCategories()` returns `QueryRow`. Plus the `build.yaml` source-set
  fix required because the module lives in `src/modules/`.
- Verification: the real `flutter test` suite passes 5/5 on Flutter 3.47.7 / Dart 3.13.5.
