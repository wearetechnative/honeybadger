---
# honeybadger-12l3
title: 'check_os_status: two names, two exit semantics, and a line that forwards neither'
status: todo
type: bug
priority: low
tags:
    - client
created_at: 2026-09-16T12:51:55Z
updated_at: 2026-09-16T12:51:55Z
---

Nothing is broken today. This is a line that says the opposite of what it does,
found while confirming that `lib/check-os-status.sh` exiting 1 on a healthy run
is not a defect - it is not, `EXIT_CODE` there is a severity code (0 PASS,
1 WARNING, 2 EOL/FAIL) and it behaves that way deliberately.

## Two things share the name

| | returns |
|-----------------------------|--------------------------------------|
| `lib/check-os-status.sh` | `exit $EXIT_CODE` - the severity |
| `check_os_status()` in `lib/_library:343` | ends on `cat "$report_file"` - `cat`'s status, so 0 |

The function never returns a severity. It returns non-zero only when it bails
early: the directory does not exist, or `require_fastfetch_json` fails.

## The line that reads wrong

`RUNME.sh:828`:

    local exit_code=0
    check_os_status "$output_dir" || exit_code=$?

and then `exit $exit_code` at line 870. That reads as "carry the OS severity out
as the audit's exit status". It cannot: the callee is the function, not the
script, and the function has no severity to give. In practice `exit_code` is 0
unless the audit could not run at all.

## Why the behaviour is nevertheless right

An audit that exits non-zero because someone's OS is approaching end of life
would be wrong. That is a finding, not a failure, and a caller - cron, a
deployment, an orchestrator - would treat it as a failed run. So the outcome is
correct; it is correct by accident rather than by intent, and the code claims
otherwise.

`set -e` on `RUNME.sh:81` is not a hazard here: both call sites (`515` and
`829`) handle the non-zero with `||`, so a WARNING does not abort the audit.
Checked, because that is where this would actually have bitten.

## What to do

Decide which behaviour is wanted and make the code say it.

- [ ] If the audit should not carry severity - the recommended reading - drop
      the `|| exit_code=$?` and exit 0, or capture it under a name that says
      what it is, with a comment stating the severity is deliberately not
      propagated
- [ ] If it should, the function has to return one, and the two call sites at
      `515` and `829` need to agree on what a non-zero means
- [ ] Either way, stop having a script and a function differ in exit semantics
      under one name. Rename one of them

## Priority

Low. This costs nothing today and is a trap for whoever next reads that exit
path believing it does what it appears to do.
