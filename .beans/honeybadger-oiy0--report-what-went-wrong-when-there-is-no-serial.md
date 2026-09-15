---
# honeybadger-oiy0
title: Report what went wrong when there is no serial
status: completed
type: task
priority: normal
tags:
    - honeybadger
created_at: 2026-09-15T21:16:30Z
updated_at: 2026-09-15T21:30:06Z
parent: honeybadger-ck4l
---

Two outcomes, because they call for different responses:

    could-not-read   no source returned anything - a machine or packaging
                     problem that can be fixed
    none-present     a source returned empty or a placeholder, which a virtual
                     machine legitimately does

The first is fixable. The second is a fact about the machine, and such an asset
needs a different key in the register rather than a repair.

Report the outcome at the end of the run where the operator sees it. Today the
client silently writes `Not available` and nobody notices until the dashboard
shows the asset as outstanding.

Record both the serial and the source it came from in `asset-inventory.txt`.

Tasks 4.1 to 4.4 in the OpenSpec change.

## Summary of Changes

`hardware-serial.txt` now holds the serial, or `could-not-read` when no source
returned a value, or `none-present` when a source answered but the hardware has
none. The distinction is tracked by whether any source could be consulted at
all: a readable sysfs file or a tool that exited 0 counts as an answer, a
missing file or a failing tool does not.

`hb_serial_report_line()` prints the outcome, and RUNME.sh calls it in a
`Hardware serial:` block just before the tarball is written, where the operator
sees it. The two outcomes read differently and a test asserts they do.

`hardware-serial-source.txt` records which source produced the value.
`generate_asset_inventory()` gained a `Serial Source` row next to
`Serial Number`, and the notes at the bottom of the table explain what the two
tokens mean. `generate_xlsx_asset_row_report()` was moved onto the same rule so
it can no longer report a placeholder as a cell value.

Archives written before this change are read back as `could-not-read`: at that
distance there is no telling which of the two applied, and the old value must
not be mistaken for data. Verified by regenerating the inventory for
`output-mbp-van-pim-pim-07-04-2026`, whose `Not available` now reads
`could-not-read` with source `unknown`.
