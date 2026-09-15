---
# honeybadger-wbq4
title: 'honeybadger: verify the Windows audit - serial disagrees with the ISO register'
status: todo
type: bug
priority: high
tags:
    - honeybadger
created_at: 2026-09-15T21:16:56Z
updated_at: 2026-09-15T21:16:56Z
---

The serial the Windows audit measures does not match what the ISO register holds
for that asset. Establish which of the two is right, and finish the Windows run
so the serial comes out machine-readable.

## Trigger

Elma's run on 2026-09-15 (`~/Downloads/elma/`):

    honeybadger-elma-20260915-compliance.md
      System:         LAPTOP-AC06CMEP
      Serial Number:  YD063JGA

    iso27001-compliance-essential.xlsx, Active Assets, row 11
      TARI-00031 | Elma Aker | AC06CMEP | Lenovo ideapad 330S

`AC06CMEP` is the suffix of the Windows hostname `LAPTOP-AC06CMEP`. Windows
generates that at install from randomness; it has no relation to the hardware.
Most likely transcribed from the neofetch banner, which shows
`elma@LAPTOP-AC06CMEP` at the top.

## What the client does

`AUDIT.ps1:115-128` reads `Get-CimInstance Win32_BIOS`.SerialNumber and filters
the known placeholder values. That is the correct method, properly done, which
makes it likely that `YD063JGA` is right and the register is wrong - but confirm
on the device before changing the register.

## To establish

1. Run `Get-CimInstance Win32_BIOS | Select SerialNumber` on Elma's laptop and
   compare with the sticker underneath.
2. The same for TARI-00034 (Richard van Os). The register says `PF-4VBTLB`,
   which departs from the Lenovo format elsewhere in the sheet (`PF50L2MR`,
   `PF3NFHJL`) in both the hyphen and the length.
3. Check whether more rows in column D hold a hostname fragment rather than a
   serial.

## To fix

1. **Write `hardware-serial.txt`.** The value is already determined but appears
   only as prose in `compliance.md:485`. Linux and macOS write it as a separate
   file; Windows must do the same, under the same name.
2. **Correct the register** once steps 1 and 2 above are confirmed.
3. **Handle the placeholder path.** When the BIOS value is filtered out,
   `"Not available (VM or unknown hardware)"` ends up in the file. That is not a
   serial and must be read server-side as "no serial", not as a literal key.

## Why this matters now

badgersbay `asset-register-identity` matches submissions on the serial. While
the register holds a hostname fragment, Elma's submission matches nothing and
lands in `reports/unmatched/`. The join key has to be clean before that change
is worth anything.
