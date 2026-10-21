# SECTION 3 — .ENV.EXAMPLE TEMPLATE

```dotenv
# ============================================================
# .env.example — M7 Grid Presenter
# Version Stamp : v1.0
# ------------------------------------------------------------
# These are NON-SECRET tunables only. No credentials, tokens or
# keys exist in this module, and none may be introduced.
# ============================================================

# The timezone offset M7 uses when asking M4 for 'today', in minutes.
DEFAULT_TZ_OFFSET_MIN=0

# Log verbosity label used by the module's log call sites.
LOG_LEVEL=info
```

Note: ZERO SECRETS ARE HARDCODED in Section 1. Every value is read from
`int.fromEnvironment` / `bool.fromEnvironment` / `String.fromEnvironment` with a safe
default.