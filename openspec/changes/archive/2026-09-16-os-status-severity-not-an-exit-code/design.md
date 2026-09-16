# Design

## Which branch of the decision

The bug offers two: make the audit carry severity, or make it clear that it
does not.

It does not, and should not. An exit status answers "did this run work". A
severity answers "what did it find". A machine that runs the audit on a schedule
has to be able to tell a broken client from a machine whose kernel is a patch
behind; collapsing the two means either the finding is invisible or every
fleet host looks like a failed job. Every existing caller already relies on
that: `RUNME.sh:515` prints a warning and continues.

So the outcome stays and the code is made to say it.

## The two names

`lib/check-os-status.sh` is a command an operator runs on one directory and
reads the answer from. For that, a severity exit code is a reasonable interface:
`0` PASS, `1` WARNING, `2` EOL/FAIL. It keeps it.

`check_os_status()` in `lib/_library` is a step inside a longer run. It writes
`os-kernel-status.txt` and prints it. Its exit status can only usefully say
whether it produced the report. That is not a check, and calling it one is what
made `RUNME.sh:829` look sensible - so it becomes `generate_os_status_report()`.

Renaming the function rather than the script, because:

- the name should describe what the thing does, and this one generates a report
- the capability spec is named `check-os-status` after the script; renaming the
  script would churn the spec, `openspec/project.md` and `CACHE-INTEGRATION.md`
  for no gain
- the script's name and its severity exit code are both already right

## What the exit status of each means now

| | 0 | non-zero |
|-------------------------------|------------------|-----------------------------|
| `lib/check-os-status.sh` | PASS | 1 WARNING, 2 EOL/FAIL |
| `generate_os_status_report()` | report written | could not produce a report |
| `RUNME.sh check-output` | reports written | could not run at all |

`check-output` still exits non-zero when it genuinely cannot run: a missing
directory or archive, or a directory without `fastfetch.json`. Those already
`exit 1` on their own, before this line is reached.

## The call sites agree

Both become:

    generate_os_status_report "$output_dir" [cache] \
        || echo "  Warning: Could not complete OS/kernel analysis"

The audit path already read that way. `check_output` now does too, and exits 0
at the end instead of forwarding a status it never had.

Printing a warning rather than swallowing the failure matters: the function can
still fail for a real reason, and a run that could not analyse the OS should say
so even though it is not a failed run overall.

## Why not just delete the variable

`local exit_code=0` with nothing assigning it, and `exit $exit_code`, would
behave identically and still read as though a status were being carried. The
point of the change is that the code stops implying something it does not do, so
the variable goes and the intent is stated in a comment where the forwarding
used to be.

## What this does not fix

`lib/check-os-status.sh` remains a near-duplicate of the library path that
`RUNME.sh` never calls. That duplication is a larger question than a name, and
this change deliberately leaves it: two entry points with two honest contracts
is a smaller problem than two entry points with one name and two meanings.
