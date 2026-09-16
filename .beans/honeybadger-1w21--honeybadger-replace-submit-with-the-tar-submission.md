---
# honeybadger-1w21
title: 'honeybadger: replace submit with the tar submission'
status: completed
type: task
priority: high
tags:
    - honeybadger
    - iso27001
created_at: 2026-09-16T06:11:29Z
updated_at: 2026-09-16T06:21:27Z
---

`submit` sends one report at a time to `POST /`, which has no concept of a
hardware serial. Its submissions therefore land in
`<period>/<hostname>-<username>/` with no serial, no asset matching and no
evidence archive, and can never be attributed to an asset in the ISO register.

`submit-tar` sends the whole archive to `POST /submit-tar`, which reads
`hardware-serial.txt` from it, matches the asset, stores each extracted report
next to the archive under `submissions/<serial>/<timestamp>/`, and keeps the
archive as the evidence of record.

Only one of these two produces compliance evidence. Keeping both invites
submitting the one that does not.

## What changes

- `submit` becomes the tar submission
- `submit_all_reports()` and the single-report path are removed
- `submit-tar` stays as a deprecated alias that warns and does the same thing,
  so cron entries on colleagues' machines do not fail silently

## Why the alias

A clean break would break every cron job that still calls `submit-tar`, and it
would fail in the way that is hardest to notice: a scheduled job printing an
error nobody reads. The alias costs one branch and can be dropped once the
fleet has moved.

## Note

badgersbay keeps its `POST /` endpoint. Removing it there is a separate
decision; this bean only stops this client from using it.
