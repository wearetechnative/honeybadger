---
# honeybadger-12l3
title: 'check_os_status: two names, two exit semantics, and a line that forwards neither'
status: completed
type: bug
priority: low
tags:
    - client
created_at: 2026-09-16T12:51:55Z
updated_at: 2026-09-16T12:59:08Z
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

## Summary of Changes

Fixed in OpenSpec change `os-status-severity-not-an-exit-code`, archived as
`openspec/changes/archive/2026-09-16-os-status-severity-not-an-exit-code`.

Every claim in the report was checked against the code first and all of them
held: the function ends on `cat "$report_file"`, the script exits `EXIT_CODE`,
`set -e` is at `RUNME.sh:81`, and both call sites handle the non-zero with `||`.

### The branch taken

The audit does not carry severity, and now says so. An exit status answers "did
this run work"; a severity answers "what did it find". A caller on a schedule
has to tell a broken client from a machine whose kernel is a patch behind, and
collapsing the two makes either the finding invisible or every fleet host look
like a failed job.

### One name, one meaning

`check_os_status()` is now `generate_os_status_report()`. It writes
`os-kernel-status.txt`; its exit status says whether it produced the report.

The script keeps its name and its severity exit code - that is the right
interface for a command an operator runs on one directory and reads the answer
from. Renaming the function rather than the script, because the name should
describe what the thing does, and because the capability spec, `project.md` and
`CACHE-INTEGRATION.md` are all named after the script.

Each entry point now states its own contract where it is defined, and each names
the other so the difference is deliberate rather than discovered.

### The line itself

`local exit_code=0` / `|| exit_code=$?` / `exit $exit_code` is gone from
`check_output`. Both call sites now read identically and warn on a genuine
failure, and the reason for exiting 0 is stated where the forwarding used to be.
Leaving the variable in place unassigned would have behaved the same and still
read as though a status were being carried, which is the thing this change is
about.

### Demonstrated

| | |
|-----------------------------------------------|----------|
| `lib/check-os-status.sh` on a warning directory | exit 1 (severity) |
| `check-output` on the same directory            | exit 0 |
| the warning, still in `os-kernel-status.txt`    | `Result: WARNING` |
| `check-output`, no `fastfetch.json`             | exit 1, directory untouched |
| `check-output`, directory does not exist        | exit 1 |

### Tests

`tests/test_os_status_exit_contract.sh`, 12 assertions: a produced report is a
zero, a finding is still a zero, a missing directory and a directory without
system information are failures, the script still exits a severity, and it
documents its codes. Two guards - the old name not returning to live code, and
no status being captured from the generator again - both verified negatively by
reintroducing the fault and watching the suite fail. Tests use a pre-populated
cache directory so none of them reaches the network.

Full suite: 11 files, passing. shellcheck: unchanged on all three files.

### Left alone

- Archived changes and the CHANGELOG keep the old name: they record what the
  code was called at the time.
- The unarchived change `kernel-status-analysis` refers to `check_os_status()`
  in its delta spec. It is complete but never archived, which is bean
  honeybadger-9llx; whoever archives it will need to apply the new name.
- `lib/check-os-status.sh` is still a near-duplicate of the library path that
  `RUNME.sh` never calls. That is a larger question than a name, and two entry
  points with two honest contracts is a smaller problem than two with one name
  and two meanings.
