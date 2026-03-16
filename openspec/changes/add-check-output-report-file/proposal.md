# Change: Add Report File Generation to check-output Command

## Why
Currently, when users run the `check-output` command, all analysis output (OS/kernel status, asset inventory, and processing messages) is only displayed on the screen. This creates several issues:

1. Users cannot easily save or share the analysis results
2. Output is lost when terminal sessions end
3. No persistent record exists for compliance documentation
4. Hard to compare results across multiple re-analyses

A dedicated report file captures all terminal output for later reference, sharing with stakeholders, and compliance archiving.

## What Changes
- Add automatic report file generation to `check-output` command
- Report file will contain the same text displayed on screen during execution
- Report filename will match the tarball convention: `honeybadger-{username}-{date}-report.txt`
  - For input `output-user-09-02-2026` → `honeybadger-user-09-02-2026-report.txt`
  - For input `honeybadger-user-09-02-2026.tar.gz` → `honeybadger-user-09-02-2026-report.txt`
- Report file will be created in the current working directory alongside the tarball
- Report content includes all terminal output:
  - Initial processing messages (directory/tarball handling)
  - Release information update messages
  - Complete OS & kernel status analysis
  - Complete asset inventory table
  - Cleanup messages (if applicable)

## Impact
- Affected specs: `check-output` capability (new spec)
- Affected code:
  - RUNME.sh:401-510 (`check-output` function)
  - _library:317-397 (`check_os_status` function - minimal changes)
  - _library:654-794 (`generate_asset_inventory` function - minimal changes)
- Backwards compatible: Existing behavior unchanged, only adds new output file
- No breaking changes
