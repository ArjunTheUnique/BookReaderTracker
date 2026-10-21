# SECTION 3 — .ENV.EXAMPLE TEMPLATE

```dotenv
# ============================================================
# .env.example — INT-1 App Shell & Wiring
# Version Stamp : v1.0
# ------------------------------------------------------------
# NON-SECRET tunables only. No credentials exist anywhere in this
# app, and none may be introduced.
# ============================================================

# The daily page goal shown on the widget. Read by the SHELL and passed
# to M5 when pushing the widget payload (M4 does not output it).
DEFAULT_DAILY_GOAL_PAGES=20

# The offset the shell/grid uses when asking M4 for "today", in minutes.
DEFAULT_TZ_OFFSET_MIN=330

# Widget + logging tunables (owned by M5 / shared).
WIDGET_REFRESH_MIN=30
WIDGET_SHOW_TITLES=false
LOG_LEVEL=info
```

Note: ZERO SECRETS ARE HARDCODED in this package.
