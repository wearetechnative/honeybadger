---
# honeybadger-qt9v
title: Windows writes hardware-serial.txt with a BOM, and the Linux reader keeps it
status: in-progress
type: bug
priority: high
created_at: 2026-09-28T10:48:51Z
updated_at: 2026-09-28T11:03:05Z
---

Found on 2026-09-28 while verifying the Windows client (honeybadger-dtrv) on a
Windows 11 test laptop that is not a fleet asset.

## What happens

AUDIT.ps1:147-149 writes the serial files with `Out-File -Encoding UTF8`. On
Windows PowerShell 5.1 that writes a UTF-8 byte order mark and a CRLF line
ending, so hardware-serial.txt holds `EF BB BF` + the serial + `\r\n`, and
hardware-serial-source.txt the same around `wmi:Win32_BIOS`.

- badgersbay is not affected: `normalise_serial()` strips the BOM, and
  `.strip()` the CR. The submission resolved on the serial as it should.
- The Linux client is. `read_recorded_serial()` returns `﻿<serial>`
  with status `ok`, and HB_SERIAL_SOURCE carries the BOM as well. When
  `check-output` runs on a Windows archive - the operator's normal process,
  downloading the archive from badgersbay - the xlsx report puts an invisible
  character in front of the serial in column D. Pasted into the sheet, it
  goes into the register, and the register row stops matching the machine.

The compliance and actions reports the Windows client writes start with a BOM
too. That is cosmetic, but it is the same cause.

## To fix

1. Write the serial files from AUDIT.ps1 without a BOM and without a line
   ending the Linux side does not expect, for example
   `[System.IO.File]::WriteAllText($path, $value, [System.Text.UTF8Encoding]::new($false))`.
   Consider the same for the other text files the Windows client writes.
2. Make `read_recorded_serial()` strip a leading BOM and a trailing CR from
   both files, so archives already submitted - including the ones from
   2026-09-15 - read correctly. `is_usable_serial()` should never see either.
3. Tests: a Pester test that the written file has no BOM, and a shell test
   that a BOM + CRLF serial file reads as the bare serial with status ok.

## Done - 2026-09-28

- `Write-HbTextFile` in lib/Honeybadger.psm1 writes UTF-8 without a BOM,
  ending in one LF, and resolves a relative path against the PowerShell
  location. AUDIT.ps1 writes both serial files through it.
- `_hb_serial_clean()` strips a leading BOM; it already removed CR and LF.
  On the second test-laptop archive, `check-output`'s xlsx report now shows the
  bare serial in column D.
- Tests: `test_a_windows_serial_file_reads_as_the_bare_serial` in
  tests/test_serial_reporting.sh (fails against the old reader), and three
  Pester tests for `Write-HbTextFile`.

Only the serial files changed. fastfetch.json, asset-inventory.json and the
reports still carry a BOM; badgersbay reads archive members as bytes and jq
accepts a BOM, so nothing misreads them. bitlocker_result.txt is formatted from
objects by Out-File, and changing its writer would change its layout.

Not yet run on Windows: the Pester tests need pwsh, and the writer needs one
more audit on a Windows machine to confirm `hardware-serial.txt` starts with
the serial and not `EF BB BF`.
