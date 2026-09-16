## Why

`RUNME.sh:110` names every artifact a run produces with a hostname it obtains
like this:

    local hostname=$(hostname -s)

`hostname(1)` is not part of Arch's base install - it lives in `inetutils`,
which the cloud image does not carry. On a stock Arch host the command is not
found.

The failure is silent. `local` is a builtin that always returns 0, so the exit
status of the assignment is the declaration's, not the command's. `set -e`
never fires, nothing is printed, and `$hostname` is the empty string. The run
continues and writes `output--<user>-<date>` and
`honeybadger--<user>-<date>.tar.gz` - a hostname that is the empty string,
with nothing anywhere in the run saying so.

An archive named that way is still submitted and still stored. The operator
reading the fleet's output sees a nameless machine and has no way to tell it
from a run that simply had no hostname.

Confirmed on a stock Arch cloud image during the acceptance test for
`honeybadger-ck4l`. The agent running it worked around the problem by
installing `inetutils`, which a real fleet host would not have done.

## What Changes

- **Stop shelling out for something the shell already knows.** Resolve the
  hostname from `uname -n` (coreutils, present everywhere), then `$HOSTNAME`
  (set by bash), then `/etc/hostname`. No package is needed on any supported
  distribution.
- **Shorten in the shell, not in the tool.** `hostname -s` existed only to cut
  the domain off; `${name%%.*}` does the same with no process at all.
- **Never assign and test in one statement.** The resolver declares first and
  assigns second, so a failing source is a failing source.
- **Fail loudly when there is no hostname.** If every source comes up empty the
  audit stops with an error naming what it tried, rather than writing an
  archive whose name has a hole in it.
- **Reject a value that cannot name a file.** Whitespace, control characters
  and path separators are not silently carried into a filename.
- **Fix the same masking in `unpack_tarball`.** `local target_dir=$(tar ...)`
  at `RUNME.sh:705` hid the exit status of a `tar` listing the same way.
- **Keep the pattern out.** A test asserts `RUNME.sh` contains no
  `local x=$(cmd)`, so the next occurrence fails the suite instead of a fleet
  host.

## Capabilities

### Modified Capabilities
- `audit-output`: how the run names its output directory and tar archive, which
  sources the hostname is resolved from, and what happens when none of them
  answer

## Impact

- Arch hosts produce correctly named output without `inetutils` installed.
- A run that genuinely cannot determine a hostname now stops instead of
  submitting an archive named `honeybadger--<user>-<date>.tar.gz`.
- No behaviour change on hosts where `hostname -s` already worked: `uname -n`
  reports the same name and `${name%%.*}` shortens it identically.
- `lib/_library` gains `hb_resolve_short_hostname()`; `RUNME.sh` is its only
  caller.

## Non-goals

- The other `local x=$(cmd)` occurrences in `lib/_library`. They are audited as
  part of this change and left alone deliberately: each one pairs a command
  that may legitimately produce nothing with `2>/dev/null` and a fallback, so
  the masked status is the intended behaviour rather than a defect. The guard
  test is scoped to `RUNME.sh` for that reason.
- Windows. `AUDIT.ps1` does not use `hostname(1)`.
- The Arch `python` / `python3` package-name note recorded alongside this bug.
  The repository contains no `pacman -S python3` instruction, so there is
  nothing to correct here; it is tracked separately.
