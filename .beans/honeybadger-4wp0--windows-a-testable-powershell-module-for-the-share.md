---
# honeybadger-4wp0
title: 'Windows: a testable PowerShell module for the shared audit logic'
status: completed
type: task
priority: high
created_at: 2026-09-18T08:39:55Z
updated_at: 2026-09-18T08:46:06Z
parent: honeybadger-k80g
---

AUDIT.ps1 and submit-report.ps1 are top-to-bottom scripts, so nothing in them can be tested without a Windows host. Extract the platform-independent logic into lib/Honeybadger.psm1 - serial usability, fastfetch parsing, the asset-inventory document, output and archive naming, configuration loading, submission outcome classification - so it runs under pwsh on Linux and the suite can exercise it.

This is the enabler for every other task in honeybadger-k80g: without it the Windows client stays unverifiable.


## Summary of Changes

lib/Honeybadger.psm1 holds the logic that is not Windows-specific: the serial
usability rule, the fastfetch parser, the inventory document and its scalar
rules, output/archive/report naming, configuration precedence, and submission
URI and outcome classification. Every function takes its inputs as parameters
and touches no Windows API, so the whole of it runs under pwsh on Linux.

Verified against the Linux implementation: the parser turns captured fastfetch
output into the same flat snake_case object RUNME.sh produces with jq, and
New-HbAssetInventory renders byte-comparable schema_version 2 documents.
