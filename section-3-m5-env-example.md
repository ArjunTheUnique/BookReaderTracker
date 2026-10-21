# SECTION 3 — .ENV.EXAMPLE TEMPLATE

```dotenv
# ============================================================
# .env.example — M5 Widget Bridge
# Version Stamp : v1.0
# ------------------------------------------------------------
# These are NON-SECRET tunables only. No credentials, tokens or
# keys exist in this module, and none may be introduced.
# ============================================================

# How often the widget is asked to refresh, in minutes.
WIDGET_REFRESH_MIN=30

# Whether the widget may show book titles (privacy: numbers only by default).
WIDGET_SHOW_TITLES=false

# Log verbosity label used by the module's log call sites.
LOG_LEVEL=info
```

Note: ZERO SECRETS ARE HARDCODED in Section 1. Every value is read from
`int.fromEnvironment` / `bool.fromEnvironment` / `String.fromEnvironment` with a safe
default.