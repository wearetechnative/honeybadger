---
# honeybadger-1pyf
title: 'honeybadger: read system information from fastfetch only'
status: todo
type: task
priority: normal
tags:
    - honeybadger
created_at: 2026-09-16T09:03:08Z
updated_at: 2026-09-16T09:03:08Z
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
