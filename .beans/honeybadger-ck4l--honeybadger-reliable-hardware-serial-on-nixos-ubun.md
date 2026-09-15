---
# honeybadger-ck4l
title: 'honeybadger: reliable hardware serial on NixOS, Ubuntu, Debian, Arch and macOS'
status: in-progress
type: epic
priority: high
tags:
    - honeybadger
    - iso27001
    - serial
created_at: 2026-09-15T21:16:29Z
updated_at: 2026-09-15T21:32:46Z
---

The hardware serial is the key the collection server matches submissions to
assets on. Roughly half the fleet never determines one, and on macOS the audit
writes something that looks like data but is not.

## Note on identifiers

This epic was originally created as `wtoorren-df2n` in the personal beans
project, before honeybadger had one of its own. Commit 7c71b05, which added the
OpenSpec change, still names the old identifier.

## OpenSpec

This epic is delivered through the existing change:

    openspec/changes/reliable-hardware-serial/

It holds the proposal, design, tasks and the `hardware-serial-collection`
capability. Do not create it again - implement, test, archive.

## Problem

Across the 22 archives stored on compute2-prod, five systems carry a usable
serial. The rest do not:

    Not available        technative-casper-casper    (4 archives)
    Not available        nixos-pankhurip             (4 archives)
    Not available        SammyMBPro-Sammy            (macOS)
    "Mac OS X<TAB>"      MBP-van-pim-pim             (macOS)

`RUNME.sh:171-175` silently writes `Not available` whenever `dmidecode` is not
in PATH. This is not a privilege problem: `RUNME.sh:84` already requires root
and exits otherwise. The tool is simply not installed - on NixOS it is not in
PATH by default.

The kernel already holds the value:

    $ sudo cat /sys/class/dmi/id/product_serial
    PF50L2MR

No tool, no network, no package, and the same sysfs path on NixOS, Ubuntu,
Debian and Arch.

## Acceptance criteria

1. An audit on NixOS without `dmidecode` in PATH produces a usable serial -
   exactly the case that fails today for technative-casper and nixos-pankhurip.
2. The same on Ubuntu, Debian and Arch, through the same code path with no
   distribution-specific handling.
3. An audit on macOS produces the serial shown in About This Mac, and never
   again a fragment of unrelated output.
4. An unusable value is never written as though it were a measurement. The rule
   is the one the collection server applies: one token, no whitespace, no
   placeholder, not all zeroes.
5. When no source returns anything, the file holds `could-not-read`. When a
   source returns an empty or placeholder value - as a virtual machine
   legitimately does - it holds `none-present`. Both are reported at the end of
   the run where the operator sees them.
6. `dmidecode` does not become a hard dependency. The audit does not fail on a
   machine where sysfs works.
7. `asset-inventory.txt` records both the serial and the source it came from.
8. Tests cover the validation function against the real values found on
   compute2, the Linux chain with each source stubbed in turn, and the macOS
   parser against real `ioreg` and `system_profiler` output.

## Done when

Every criterion above is demonstrably met, the tests pass, and the OpenSpec
change is implemented and archived.

Manual verification is part of it: run the audit on NixOS, on a Debian
derivative, on Arch and on a Mac, and confirm the value matches what the
hardware itself reports.

## Out of scope

Windows. `AUDIT.ps1` already reads `Win32_BIOS.SerialNumber` correctly; it only
fails to write the value to a file, which is honeybadger-k80g.

## Implementation status (15-09-2026)

Implemented, tested and archived. Commits `39900d7` and `d8778fa` on
`openspec/fastfetch-and-asset-inventory`. OpenSpec change archived as
`openspec/changes/archive/2026-09-15-reliable-hardware-serial/`, capability
synced to `openspec/specs/hardware-serial-collection/`.

Acceptance criteria:

    1  NixOS without dmidecode in PATH     MET - PF50L2MR via sysfs:product_serial
    2  Ubuntu, Debian, Arch, same path     MET - all three, dmidecode absent
    3  macOS matches About This Mac        NOT DEMONSTRATED - honeybadger-1lo9
    4  never write an unusable value       MET - one shared gate, 35 assertions
    5  could-not-read vs none-present      MET - both written and reported
    6  dmidecode not a hard dependency     MET - and a test fails if added
    7  asset-inventory records the source  MET - Serial Source row
    8  tests cover all three areas         MET - 133 assertions, shellcheck clean

Criterion 3 is the one gap: no Mac was reachable from the machine this was
implemented on. The parsers are unit tested against fixtures written to the
exact output format of `ioreg` and `system_profiler`, including the
neighbouring properties the old implementation picked up by mistake, and the
whole macOS chain is exercised with both tools stubbed. What is left is running
the audit on a Mac and comparing with About This Mac - honeybadger-1lo9.

The epic stays in-progress until that is done.
