---
# honeybadger-s34v
title: Let environment variables override the config file
status: todo
type: task
priority: high
tags:
    - honeybadger
    - config
created_at: 2026-09-16T06:27:27Z
updated_at: 2026-09-16T06:27:27Z
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
