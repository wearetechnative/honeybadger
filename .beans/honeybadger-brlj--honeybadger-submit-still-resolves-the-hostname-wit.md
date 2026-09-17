---
# honeybadger-brlj
title: 'honeybadger: submit still resolves the hostname with hostname(1)'
status: completed
type: bug
priority: high
created_at: 2026-09-16T13:11:07Z
updated_at: 2026-09-17T11:59:21Z
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

## Plan

- [x] OpenSpec change `fix-submit-hostname-resolution` proposed
- [x] `submit_tar_file()` resolves the hostname with `hb_resolve_short_hostname`
- [x] Submission stops rather than sending an empty `X-Hostname`
- [x] Guard test widened from `RUNME.sh` to every shipped shell source
- [x] Submission suite no longer links `hostname(1)` into its stub PATH
- [x] Suite green, OpenSpec validated
- [x] CHANGELOG updated, change archived, committed

## Correction: it did not abort

This bean predicted that `set -e` would make the missing command abort the
submission. It does not. `set -e` is set inside `audit()`, not at the top of
`RUNME.sh`, so the submit path runs without errexit and the failing
assignments status is discarded by the next statement.

Run against a real server on a PATH without `hostname(1)`:

    lib/_library: line 1819: hostname: command not found
    Submitting tar file (attempt 1/1)...
    ✓ Successfully submitted tar file: honeybadger-...tar.gz
    Submission complete!

Exit 0, and the server logged no `X-Hostname` header at all - curl drops a
header whose value is empty. So the quieter failure this bean named second was
the only one: evidence stored against a machine with no name, reported to the
operator as a success. Worse than the abort, and it is what the fix is measured
against.

## Summary of Changes

OpenSpec change `2026-09-17-fix-submit-hostname-resolution`.

- `submit_tar_file()` resolves the hostname with `hb_resolve_short_hostname()`,
  the chain `RUNME.sh` already uses, and returns 1 naming `uname -n`,
  `$HOSTNAME` and `/etc/hostname` when none of them answers. No submission goes
  out that the server cannot attribute to a named machine.
- The guard test covers `RUNME.sh`, `lib/_library` and `lib/*.sh` instead of
  `RUNME.sh` alone, and catches a bare `$(hostname)` as well as the `-s` and
  `-f` forms. Full-line comments are stripped, so the prose recording what
  `hostname -s` used to do is not reported. Verified by injecting each shape.
- The submission suite linked the real `hostname(1)` into its stub PATH, so the
  condition this defect needs could not arise in a test; and its assertion
  `X-Hostname: ` was satisfied by an empty value. Both fixed: the tool is gone
  from the stub PATH, the chain is pinned to a known name, and four tests now
  cover the resolved name, shortening, a loudly failing `hostname(1)`, and the
  refusal to submit without a hostname.

Verified against the unfixed code: the new submission tests fail 9 assertions
and the guard names `lib/_library:1819`. End-to-end against a real HTTP server
on a PATH without `hostname(1)`, the fixed client sends `X-Hostname: lobos`;
the unfixed one sent no header and printed `Submission complete!`.

Specs `report-submission` and `audit-output` updated. Full suite green (11
files), `openspec validate --all` 22/22, no new shellcheck findings.
