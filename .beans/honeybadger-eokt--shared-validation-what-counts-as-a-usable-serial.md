---
# honeybadger-eokt
title: 'Shared validation: what counts as a usable serial'
status: completed
type: task
priority: high
tags:
    - honeybadger
created_at: 2026-09-15T21:16:29Z
updated_at: 2026-09-15T21:29:48Z
parent: honeybadger-ck4l
---

A usable serial is one token: non-empty, no whitespace, no placeholder, not all
zeroes. One shared function decides that, and every platform branch calls it
before anything is written.

Placeholder list, matching the collection server:

    Not available
    Not available (VM or unknown hardware)
    To Be Filled By O.E.M.
    To Be Filled
    Default string
    Not Specified
    System Serial Number
    None
    Unknown

Why identical: badgersbay applies the same rule when matching a submission to
an asset. Writing a value the server will reject anyway helps nobody, and
writing `Mac OS X` is worse than writing nothing - it looks like data.

Tasks 3.1 to 3.3 in the OpenSpec change.

## Summary of Changes

`is_usable_serial()` in `lib/_library` is the single gate. A usable serial is one
token: non-empty, no whitespace, no control characters, not all zeroes and not
one of the nine placeholders in `HB_SERIAL_PLACEHOLDERS`, compared
case-insensitively. It also rejects the two tokens the tool writes itself, so
re-reading an output directory cannot mistake a marker for data.

Every platform branch calls it before anything is written, and so do
`generate_asset_inventory()` and `generate_xlsx_asset_row_report()` through
`read_recorded_serial()`.

Covered by `tests/test_serial_validation.sh` (35 assertions) against the real
values found on compute2.
