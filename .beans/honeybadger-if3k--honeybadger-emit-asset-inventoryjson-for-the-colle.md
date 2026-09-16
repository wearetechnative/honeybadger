---
# honeybadger-if3k
title: 'honeybadger: emit asset-inventory.json for the collection server'
status: completed
type: feature
priority: high
tags:
    - honeybadger
    - iso27001
created_at: 2026-09-16T07:55:33Z
updated_at: 2026-09-16T07:55:33Z
---

The audit determines every value the ISO register needs and writes them twice,
both times for humans: `asset-inventory.txt` as a formatted table, and
`honeybadger-{user}-{date}-xlsx.md` as cell values to retype by hand.

`asset-inventory.json` is the same findings in a shape the collection server can
read, so badgersbay can fill the register columns instead of an operator
retyping them.

## Summary of Changes

Emitted from the determinations the xlsx report already renders, not derived
again. Whether a disk counts as encrypted or a hardening score as compliant is
platform-specific knowledge that lives in this client; a second implementation
of those rules in the server would drift from it.

Each finding carries the value and the finding it came from, because "Yes" and
"Yes (LUKS)" answer different questions. A value the audit could not determine,
or deliberately declines to assert - vulnerable packages, where the spreadsheet
contradicts itself about which value means compliant - is `null` with the
finding intact. That is distinguishable from an absent key, which means this
generation does not report the field at all.

`audit` now also runs the xlsx report, which is what writes the JSON into the
output directory before the archive is created. Without that the file would only
have appeared when someone ran `check-output` afterwards, and never in a
submitted archive.

Verified against the real archive from lobos: all seven values match the xlsx
report's cell values exactly, the serial matches, and the file travels in the
tar beside `hardware-serial.txt`.

New capability `asset-inventory-json`; change archived as
`2026-09-16-emit-asset-inventory-json`. 21 assertions in
`tests/test_asset_inventory_json.sh`; seven test files pass.

## Follow-up

badgersbay does not read this file yet. Consuming it is what fills the
compliance columns in the fleet view.
