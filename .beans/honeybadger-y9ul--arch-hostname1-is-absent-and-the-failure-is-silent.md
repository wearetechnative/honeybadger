---
# honeybadger-y9ul
title: 'Arch: hostname(1) is absent and the failure is silent'
status: todo
type: bug
priority: high
tags:
    - arch
    - client
created_at: 2026-09-16T10:05:28Z
updated_at: 2026-09-16T10:05:28Z
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
