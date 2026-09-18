---
# honeybadger-rwg5
title: 'Windows: emit asset-inventory.json in the existing schema'
status: completed
type: task
priority: high
created_at: 2026-09-18T08:40:27Z
updated_at: 2026-09-18T09:01:00Z
parent: honeybadger-k80g
---

The Windows client produces no machine-readable summary at all, so a Windows submission gives badgersbay nothing to file. Emit asset-inventory.json per the asset-inventory-json capability - schema_version 2, identity block, value-and-provenance per finding - with platform "windows".

Do not invent a second shape. HardeningKitty has no Lynis 0-100 score, so hardening_score.tool is hardeningkitty and, where there is no comparable figure, value is null with a finding saying so. The determinations come from the checks AUDIT.ps1 already makes, not from a second evaluation of the same data.


## Summary of Changes

AUDIT.ps1 writes asset-inventory.json in generation 2 with platform windows,
built from the determinations the compliance report renders rather than from a
second evaluation of the collected data.

hardening_score carries a null value, tool hardeningkitty and the measured
counts, because HardeningKitty reports pass/fail by severity and not a 0-100
figure; a number invented for that column would be compared against the Linux
fleet real Lynis scores. vulnerable_packages carries a null count - nothing
looked, which is not a measured zero.

Serialised at depth 8: ConvertTo-Json truncates at 2 by default, silently, into
the string System.Collections.Hashtable.
