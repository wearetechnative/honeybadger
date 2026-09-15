## Why

`lib/check-os-status.sh` still falls back to `neofetch.json`, `neofetch.txt` and
`fastfetch.txt` when `fastfetch.json` is absent, and the script itself labels
that path "Legacy neofetch.json used - no live data" (line 560). The fallbacks
keep a retired collection format alive in the one place that most needs a single
shape to reason about.

The server side has now committed to a single name: badgersbay accepts
`fastfetch.json` and nothing else (`use-fastfetch-system-info`). The client
should carry the same commitment rather than quietly supporting output it no
longer produces.

## What Changes

- `lib/check-os-status.sh` reads `fastfetch.json` only
- Absence of `fastfetch.json` becomes a clear error naming the file, not a
  silent degradation to a format with no kernel data
- Remove the legacy-format branches and the notes that explain them

Windows is out of scope here: `AUDIT.ps1` still runs neofetch and writes ASCII
art, which is a larger piece of work tracked in bean `wtoorren-cikq`.

## Capabilities

### Modified Capabilities
- `system-information-collection`: single supported format

## Impact

- Re-running `check-output` against an output directory produced before the
  fastfetch migration will now fail with a clear message instead of producing a
  report with missing kernel comparison data. Those directories predate the
  2026-03 round and are archive material.
