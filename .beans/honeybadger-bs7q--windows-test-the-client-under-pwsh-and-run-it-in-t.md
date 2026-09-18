---
# honeybadger-bs7q
title: 'Windows: test the client under pwsh, and run it in the suite'
status: completed
type: task
priority: high
created_at: 2026-09-18T08:40:28Z
updated_at: 2026-09-18T08:59:27Z
parent: honeybadger-k80g
---

Nothing in the Windows client has ever been covered by a test. tests/run-tests.sh runs bash files only, and no PowerShell is installed on the machines this is developed on.

Add a Pester suite against lib/Honeybadger.psm1 covering the serial rule, fastfetch parsing, the inventory document, naming, configuration precedence and submission outcome classification, plus a guard that the shipped scripts no longer reference neofetch or the zip path. Wire it into tests/run-tests.sh so it runs with the rest, and skip with a clear message rather than fail when pwsh is absent.


## Summary of Changes

tests/Honeybadger.Tests.ps1 - 99 Pester tests over lib/Honeybadger.psm1 plus
guards over the shipped scripts. tests/run-tests.sh runs it after the bash
files, skipping with a message when pwsh or Pester 5 is absent so the suite
still runs on a machine with no PowerShell.

Verified against the pre-change scripts: all 13 guards fail there and pass
here. The placeholder-list test reads HB_SERIAL_PLACEHOLDERS out of
lib/_library and compares, so the two implementations of the serial rule cannot
drift silently.
