# SECTION 3 — .ENV.EXAMPLE TEMPLATE

```dotenv
# ============================================================
# .env.example — M3 Progress Logger
# Version Stamp : v1.0
# ------------------------------------------------------------
# M3 owns exactly ONE configuration value. There are no credentials,
# tokens or keys in this module, and none may be introduced.
# ============================================================

# Log verbosity label used by the module's log call sites.
LOG_LEVEL=info
```

Note: ZERO SECRETS ARE HARDCODED in Section 5. The value is read with
`String.fromEnvironment` and has a safe default.
