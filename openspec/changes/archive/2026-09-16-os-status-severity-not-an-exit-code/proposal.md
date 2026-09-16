## Why

Nothing is broken today. This is a line that says the opposite of what it does.

Two things share the name `check_os_status`, and they do not agree on what their
exit status means:

| | returns |
|-----------------------------------|---------------------------------------|
| `lib/check-os-status.sh` | `exit $EXIT_CODE` - a severity: 0 PASS, 1 WARNING, 2 EOL/FAIL |
| `check_os_status()` in `lib/_library` | ends on `cat "$report_file"`, so `cat`'s status - 0 |

The function never returns a severity. It returns non-zero only when it bails
out early: the directory does not exist, or `require_fastfetch_json` refuses it.

`RUNME.sh:829` reads as though it carries the severity out as the audit's exit
status:

    local exit_code=0
    check_os_status "$output_dir" || exit_code=$?

with `exit $exit_code` at the end of `check_output`. It cannot: the callee is
the function, not the script, and the function has no severity to give. In
practice `exit_code` is 0 unless the audit could not run at all.

The behaviour that results is the right one. An audit that exits non-zero
because someone's OS is approaching end of life would be wrong - that is a
finding, not a failure, and cron, a deployment or an orchestrator would treat it
as a failed run. But it is right by accident, and the code claims otherwise. The
two call sites also disagree in tone: `RUNME.sh:515` treats a non-zero as a
warning to print, `RUNME.sh:829` as an exit status to propagate.

`set -e` on `RUNME.sh:81` is not a hazard here: both call sites handle the
non-zero with `||`, so a WARNING does not abort the audit. Checked, because that
is where this would have bitten.

## What Changes

- **Say that severity is not propagated, and mean it.** `check_output` drops the
  `|| exit_code=$?` and `exit $exit_code`, warns on a genuine failure the way
  the audit path already does, and exits 0. A finding is reported in
  `os-kernel-status.txt` and in the compliance report, which is where a finding
  belongs.
- **Both call sites agree.** `RUNME.sh:515` and `RUNME.sh:829` become the same
  call with the same handling.
- **One name, one meaning.** `check_os_status()` becomes
  `generate_os_status_report()`. It generates `os-kernel-status.txt`; it does
  not return a verdict, and its name should not suggest one. The script keeps
  its name and its severity exit code, which are correct for a command an
  operator runs directly.
- **Both contracts written down** at the top of each, so the next reader does
  not have to derive them.

## Capabilities

### Modified Capabilities
- `check-os-status`: what an exit status means for each of the two entry points,
  and that a finding is never a failed run

## Impact

- No behaviour change for any caller. `check-output` already exited 0 on a
  WARNING; now it does so on purpose.
- `openspec/project.md` names `check_os_status()` and is updated.
- The unarchived change `kernel-status-analysis` refers to `check_os_status()`
  in its delta spec. It is complete but never archived, which is bean
  honeybadger-9llx; that text is left alone rather than edited in place, and
  whoever archives it will need to apply the new name.

## Non-goals

- Making the audit carry severity. That is the other branch of this decision and
  it is the wrong one: a finding is not a failed run.
- Merging the script and the library function. They have different jobs - one is
  a command an operator runs, the other a step inside a longer run - and the
  duplication between them is its own question.
