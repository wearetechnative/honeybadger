## Why

`submit_tar_file()` in `lib/_library:1819` still names the machine a submission
is attributed to with the tool the previous change removed:

    hostname=$(hostname -s)

This is the defect fixed in `2026-09-16-reliable-hostname-resolution`, standing
in a second place. That change replaced the call in `RUNME.sh` and added
`hb_resolve_short_hostname()` to `lib/_library`; this occurrence was not
changed, and the guard test written to stop it coming back greps `RUNME.sh`
alone.

`hostname(1)` lives in `inetutils`, which Arch's base install does not carry.
Run against a real server on a PATH without the tool, the unfixed client does
this:

    lib/_library: line 1819: hostname: command not found
    Submitting tar file (attempt 1/1)...
    ✓ Successfully submitted tar file: honeybadger-...tar.gz
    Submission complete!

Exit status 0, and the server logged no `X-Hostname` header at all - curl drops
a header whose value is empty. The archive is stored against a machine with no
name, and the operator is told the submission succeeded.

It is worth being exact about why it does not simply abort, because the line
looks as though it should. `set -e` is set inside `audit()`, not at the top of
`RUNME.sh`, so the submit path runs without errexit; the failing assignment's
status is discarded by the next statement. The original occurrence was masked
by `local`, this one by the absence of anything that reads the status. The
outcome is the same in both cases - the failure produces no message anyone
sees - and it is the reason the fix has to check the resolver's status
explicitly rather than rely on the shell noticing.

badgersbay stores what the header says. A submission that arrives without one
is evidence filed against nothing.

## What Changes

- **Resolve the submission's hostname the way the audit already does.**
  `submit_tar_file()` calls `hb_resolve_short_hostname()`, which is in
  `lib/_library` already and already tested.
- **Stop rather than send a nameless submission.** When no source yields a
  usable hostname, `submit` reports what it tried and returns non-zero, instead
  of posting an archive the server can only file against an empty name.
- **Widen the guard to every shipped shell source.** The test greps `RUNME.sh`
  and `lib/` rather than `RUNME.sh` alone, so a third occurrence fails the
  suite. It also catches a bare `$(hostname)`, which the old pattern - anchored
  on `-s` and `-f` - would have let through.
- **Stop the submission suite from supplying the tool.** Its stub PATH linked
  the real `hostname(1)` in, so the very condition this defect appears under
  could not arise in a test. The header assertions were satisfied by an empty
  value as well, and now assert the resolved name.

## Capabilities

### Modified Capabilities
- `report-submission`: where the `X-Hostname` header's value comes from, and
  what a submission does when no hostname can be determined
- `audit-output`: the guard against `hostname(1)` returning, widened from
  `RUNME.sh` to every shell source the audit ships

## Impact

- Arch hosts without `inetutils` submit with their real hostname. Before this,
  the submission went out nameless and was reported as successful.
- A submission that cannot be attributed to a named machine is not sent, and
  says so. This is a new visible failure where there was previously a silent
  success; it is the same trade the audit itself already makes when it refuses
  to name output `output--<user>-<date>`.
- No behaviour change where `hostname -s` worked: `uname -n` reports the same
  name and `${name%%.*}` shortens it identically.
- `hb_resolve_short_hostname()` gains a second caller. No new function, no new
  dependency.

## Non-goals

- The `local x=$(cmd)` occurrences elsewhere in `lib/_library`. They were
  audited by the previous change and left deliberately; nothing here revisits
  that.
- Windows. `AUDIT.ps1` and `submit-report.ps1` do not shell out to
  `hostname(1)`.
