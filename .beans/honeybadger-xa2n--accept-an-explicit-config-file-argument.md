---
# honeybadger-xa2n
title: Accept an explicit config file argument
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

There is no way to name a configuration file. The search order starts at
`./.honeybadger.conf`, which in a checkout of this repository is the production
configuration - so running the audit from the repository submits to production
whatever was intended.

Add an argument, for example `--config <file>`, that skips the search entirely.
Combined with the environment override this makes a test run safe without
moving any file.

Report which file was loaded, as it already does, so a run that picked the
wrong one is visible in its own output rather than only in the result.

## Summary of Changes

`load_server_config` takes an optional path and skips the search order when
given one. `submit` parses `--config <file>` and `--config=<file>`, and
`HONEYBADGER_CONFIG` does the same from the environment; the argument wins over
the variable.

A named file that does not exist is an error naming the path, rather than a
fallback to the search order - falling back would submit somewhere the caller
did not ask for.

Verified: `./RUNME.sh submit --config <file>` loads the named file and reports
an endpoint away from production, with the production config still sitting in
the working directory.
