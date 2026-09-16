---
# honeybadger-1pyf
title: 'honeybadger: read system information from fastfetch only'
status: completed
type: task
priority: normal
tags:
    - honeybadger
created_at: 2026-09-16T09:03:08Z
updated_at: 2026-09-16T12:43:30Z
---

`lib/check-os-status.sh` still falls back to `neofetch.json`, `neofetch.txt` and
`fastfetch.txt` when `fastfetch.json` is absent, and labels that path "Legacy
neofetch.json used - no live data" itself at line 560.

The collection server accepts `fastfetch.json` and nothing else, and has since
badgersbay `use-fastfetch-system-info`. Supporting formats this client no longer
produces keeps a retired shape alive in the code that most needs one shape.

## OpenSpec

The change already exists and was never executed:

    openspec/changes/fastfetch-only-system-info/   0/5 tasks

Proposal, tasks and a `system-information-collection` delta that removes the
backward-compatibility requirement. Do not create it again - implement, test,
archive.

## Acceptance criteria

1. `check-os-status.sh` reads `fastfetch.json` only.
2. A missing `fastfetch.json` exits with an error naming the file and the
   command that produces it, rather than degrading silently to a format with no
   kernel data.
3. A directory holding only a legacy format is treated as missing system
   information, not as a fallback.
4. `check-output` on a current output directory is unchanged.

## Out of scope

Windows. `AUDIT.ps1` still runs neofetch and writes ASCII art; that is
`honeybadger-k80g`.

## Note

Output directories produced before the fastfetch migration will stop working
with `check-output`. They predate the 2026-03 audit round and are archive
material - the archives themselves stay readable, it is only the re-analysis
that no longer accepts them.

## Summary of Changes

Implemented, tested and archived the existing OpenSpec change
`fastfetch-only-system-info`, now at
`openspec/changes/archive/2026-09-16-fastfetch-only-system-info`. It was not
recreated; it was extended with two delta specs it was missing.

### The change's own scope was too narrow

`lib/check-os-status.sh` is a standalone duplicate that `RUNME.sh` never calls.
The path the client actually runs is `extract_os_info()` and `check_os_status()`
in `lib/_library`, which carried the same fallback chain. Fixing only the script
would have satisfied the tasks while changing no behaviour at all.

Both were fixed, and `require_fastfetch_json()` refuses a directory before
anything is fetched or written.

### Legacy branches removed rather than left unreachable

With the directory refused at the door, the remaining `neofetch` branches in
`generate_asset_inventory()`, Nix detection, `is_nixos()`, the xlsx report and
`hb_audit_username()` could no longer be reached. Left in place they would be
dead code that still reads as support, so they are gone. The library now
mentions a retired format only in the gate's own error message.

### Two spec deltas the change was missing

The change carried only a `system-information-collection` delta, but two other
specs still promised the fallback:

- `check-os-status` required the chain `neofetch.json` → `neofetch.txt` →
  `fastfetch.txt` outright
- `audit-identity-resolution` - written two changes ago - had a scenario
  "Older archives still read back" taking the username from those files

Both were removed and restated. Without this the specs would have contradicted
the code and each other.

### Acceptance criteria

1. `check-os-status.sh` reads `fastfetch.json` only - `FETCH_FORMAT` and every
   text-parsing branch are gone, with a guard test against reintroduction.
2. A missing `fastfetch.json` exits naming the file and
   `sudo ./RUNME.sh audit`, and names any retired format found beside it.
3. A directory holding only a legacy format is refused, and nothing is written
   into it - demonstrated against the real
   `output-mbp-van-pim-pim-07-04-2026`.
4. `check-output` on a current directory is unchanged - demonstrated by
   regenerating every artifact from `output-lobos-wtoorren-15-09-2026` with the
   pre-change code and with the new code: the three reports,
   `asset-inventory.json`, `asset-inventory.txt` and `os-kernel-status.txt` are
   all byte-identical.

### Also fixed

`hb_audit_username()` and `hb_report_basename()` called `basename(1)`. Removing
the legacy branches meant the directory-name fallback was now reached under the
serial tests' deliberately restricted PATH, where `basename` is absent. Replaced
with parameter expansion - no process, no PATH dependency.

### Tests

`tests/test_fastfetch_only.sh`, 21 assertions: the gate accepting and refusing,
the wording of the error, each retired format refused rather than used,
extraction reading only `fastfetch.json`, `check_os_status` refusing and writing
nothing into the directory, and a guard test that no retired filename is read
anywhere in the client - verified negatively by reintroducing one and watching
the suite fail. Full suite: 10 files, passing. shellcheck: three fewer findings
in `lib/_library`, two fewer in `lib/check-os-status.sh`, none new anywhere.

### Note

`lib/check-os-status.sh` exits 1 on a healthy directory. That is not a bug:
`EXIT_CODE` is a findings-severity code (0 clean, 1 warning, 2 critical), and it
behaves identically before and after this change.
