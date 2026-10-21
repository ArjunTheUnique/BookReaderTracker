# SECTION 2 — DELIVERABLE FILE PATHS

| File | Purpose |
|---|---|
| `src/main.dart` | app entry point; builds the wiring, then runs the shell |
| `src/app/app_shell.dart` | the UI: 6x6 home grid, category, book, add-book, settings |
| `src/app/routes.dart` | maps a widget deep link (`shelf://book/<id>`) to a screen |
| `src/app/wiring.dart` | the composition root — the ONLY place the real adapters exist |
| `tests/test_integration_end_to_end.dart` | the end-to-end suite (E2E-1 … E2E-6) |
