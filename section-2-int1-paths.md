# SECTION 2 — DELIVERABLE FILE PATHS

Unchanged INT-1 files (re-sent at v1.0.1 because the passport stamp moved):

| File | Purpose |
|---|---|
| `src/main.dart` | app entry point |
| `src/app/app_shell.dart` | the UI |
| `src/app/routes.dart` | deep-link routing |
| `src/app/wiring.dart` | the composition root |
| `tests/test_integration_end_to_end.dart` | the end-to-end suite (passport now v1.0.1) |

The two files actually CHANGED by this order:

| File | Change |
|---|---|
| `src/modules/m6_backup_vault_adapters.dart` | crypto import prefixed `as crypto` |
| `src/modules/m2_book_intake_adapters.dart` | file_picker 13.1.0 API |
