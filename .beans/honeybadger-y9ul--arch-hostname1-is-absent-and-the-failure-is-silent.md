---
# honeybadger-y9ul
title: 'Arch: hostname(1) is absent and the failure is silent'
status: completed
type: bug
priority: high
tags:
    - arch
    - client
created_at: 2026-09-16T10:05:28Z
updated_at: 2026-09-16T11:28:29Z
---

`RUNME.sh` determines the output directory name with:

    local hostname=$(hostname -s)

`hostname(1)` is not part of Arch's base install - it lives in `inetutils`,
which the cloud image does not carry. The command is simply not found.

## Why this is worse than a missing command

`local` always returns 0. The assignment's exit status is the declaration's, not
the command's, so `set -e` never fires and no error is printed. The variable is
empty and the run continues.

The result is an output directory named `output--<user>-<date>` - a hostname
that is the empty string, silently. Nothing in the run says anything went wrong.

Confirmed on a stock Arch cloud image during the acceptance test for
`honeybadger-ck4l`. The agent worked around it by installing `inetutils`, which
a real fleet host would not have done.

## Fix

Do not shell out for something the shell already knows. `$HOSTNAME` is set by
bash; `uname -n` is in coreutils and universally present; `/etc/hostname` is the
last resort. Whichever is used, assign and test separately so a failure is a
failure:

    local hostname
    hostname=$(uname -n) || return 1
    hostname=${hostname%%.*}

The same pattern - `local x=$(cmd)` - should be looked for elsewhere in the
client; every occurrence hides its own exit status the same way.

## Also found on Arch, unrelated to this bug

The package is `python`, not `python3`. `pacman -S python3` fails outright, so
any Arch install instructions that name `python3` are wrong.

## Summary of Changes

Fixed in OpenSpec change `reliable-hostname-resolution`, archived as
`openspec/changes/archive/2026-09-16-reliable-hostname-resolution`.

### The resolver

`hb_resolve_short_hostname()` in `lib/_library` replaces `hostname -s`. It
tries, each only when the previous produced nothing usable:

1. `uname -n` - coreutils, asks the kernel, so it cannot be stale
2. `$HOSTNAME` - set by bash, needs no executable at all
3. `/etc/hostname` - read with the `read` builtin, so this source needs no
   coreutils either

`hostname -s` existed only to cut the domain off; `${candidate%%.*}` does the
same with no process. `hb_usable_hostname()` rejects a candidate that cannot
name a file - empty, whitespace, control characters, a `/` - and falls through
to the next source rather than aborting, so a bad `/etc/hostname` cannot stop a
run that `uname -n` could have answered. `localhost` is accepted: it is what
the machine is called, and substituting something else would invent data.

### Failing loudly

`RUNME.sh` declares and assigns in separate statements and exits non-zero when
resolution fails, naming all three sources in the error - before `mkdir -p
$output`, so no directory named `output--<user>-<date>` can be created.

### The masking, elsewhere

`unpack_tarball` had the same defect on its `tar` listing (`RUNME.sh:705`);
split and checked. shellcheck confirms both SC2155 warnings in `RUNME.sh` are
gone with no new findings.

The ~80 `local x=$(cmd)` occurrences in `lib/_library` were read and
deliberately left alone: each pairs a command that may legitimately produce
nothing (`jq` on an absent key, `date` on an unparseable string, `grep` on a
missing line) with `2>/dev/null` and a fallback, so the masked status is the
intent there. The reasoning is recorded in the change's `design.md`.

### Tests

`tests/test_hostname_resolution.sh`, 35 assertions: each source winning in
turn with `uname` stubbed via `PATH`, shortening, every rejection case, a file
without a trailing newline, `localhost`, and the failure path returning
non-zero with no output. Two guard tests fail the suite if a `local x=$(cmd)`
or a `hostname -s` is reintroduced into `RUNME.sh`. Full suite: 8 files, 236
assertions, passing.

### Demonstrated

With `hostname(1)` removed from `PATH` entirely - the stock-Arch condition -
the old code produced `output--someuser-16-09-2026` at exit status 0 and said
nothing; the new resolver returns `lobos`.

### The Arch python note

Recorded separately as honeybadger-4t57. The repository contains no
`pacman -S python3` instruction, so there was nothing to correct here.
