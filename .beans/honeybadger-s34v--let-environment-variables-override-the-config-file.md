---
# honeybadger-s34v
title: Let environment variables override the config file
status: completed
type: task
priority: high
tags:
    - honeybadger
    - config
created_at: 2026-09-16T06:27:27Z
updated_at: 2026-09-16T06:42:36Z
parent: honeybadger-6dkw
---

`load_server_config` sets defaults and then sources the config file, so the
file always wins:

    SERVER_URL="${SERVER_URL:-http://localhost:7123/}"   # default
    source "$config_file"                                 # overwrites it

Turn it around: source the file first, then let an already-set environment
variable take precedence. Then this works, which today it does not:

    SERVER_URL=http://localhost:7123/ ./RUNME.sh submit

Keep the precedence explicit and documented, because a config file that can be
silently overridden is its own kind of surprise. Order should read: environment
variable, then config file, then built-in default.

Test that a variable set in the environment survives the load, and that one
that is not set does not clobber the file value with a default.

## Summary of Changes

`load_server_config` now captures which settings the environment supplied
before sourcing the config file, then restores them over whatever the file set.
Built-in defaults apply only to settings neither source supplied.
`${!name+set}` distinguishes unset from set-but-empty, so an intentionally
empty token is not refilled from the file.

The settings the environment supplied are reported:

    Loading configuration from: ./.honeybadger.conf
    From the environment (overriding the file): DRY_RUN

Verified end to end: `DRY_RUN=true ./RUNME.sh submit` is now a dry run against
the real configuration, which is the case that submitted a real archive twice.
