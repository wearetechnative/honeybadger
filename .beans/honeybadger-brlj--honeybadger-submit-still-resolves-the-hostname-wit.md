---
# honeybadger-brlj
title: 'honeybadger: submit still resolves the hostname with hostname(1)'
status: todo
type: bug
priority: high
created_at: 2026-09-16T13:11:07Z
updated_at: 2026-09-16T13:11:07Z
---

`submit_tar_file()` in `lib/_library:1819` still determines the hostname the
submission is attributed to with:

    hostname=$(hostname -s)

This is the defect fixed in honeybadger-y9ul, in a second place. That fix
replaced the call in `RUNME.sh` and added `hb_resolve_short_hostname()` to
`lib/_library`, but this occurrence was not changed.

## Why the guard did not catch it

The regression test added with honeybadger-y9ul greps `RUNME.sh` only:

    tests/test_hostname_resolution.sh
      test_runme_no_longer_invokes_the_hostname_tool()

The reasoning at the time was that `lib/_library`'s other occurrences were
deliberate. That was about the `local x=$(cmd)` pattern, and it was allowed to
scope the `hostname -s` guard the same way. It should not have been: there is no
deliberate use of `hostname(1)` anywhere.

## What it costs

`hostname(1)` lives in `inetutils` and is not in Arch's base install. This line
is not `local hostname=$(...)`, so its exit status is the command's - and
`RUNME.sh:81` sets `set -e`. On a host without the package, `submit` aborts on
this line rather than submitting.

Where the command exists but prints nothing usable, `X-Hostname` is submitted
empty. badgersbay reads that header and stores it, so a submission is attributed
to a machine with no name.

## Fix

    hostname=$(hb_resolve_short_hostname) || return 1

The function is already in `lib/_library` and already tested.

Widen the guard test to `lib/` as well as `RUNME.sh`, so a third occurrence
cannot appear.

## Found

While reading the submission path for honeybadger-9llx.
