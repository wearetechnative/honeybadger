---
# honeybadger-1lo9
title: Verify the hardware serial on a real Mac
status: todo
type: task
priority: normal
created_at: 2026-09-15T21:29:30Z
updated_at: 2026-09-15T21:29:30Z
parent: honeybadger-ck4l
---

Task 6.4 of the reliable-hardware-serial change, which could not be done at
implementation time: no Mac was reachable from the machine the epic was
implemented on.

What is already covered:

  - hb_parse_ioreg_serial and hb_parse_system_profiler_serial are unit tested
    against fixtures written to the exact output format of both tools, including
    the neighbouring properties (IOPlatformUUID, Hardware UUID) that the old
    implementation picked up by mistake
  - the whole macOS chain is exercised with ioreg and system_profiler stubbed:
    ioreg first, system_profiler as fallback, a virtual Mac yielding
    none-present, neither tool present yielding could-not-read

What is left:

    sudo ./RUNME.sh audit

on a Mac, then confirm that hardware-serial.txt matches the serial in
About This Mac, and capture the real output of both tools into
tests/fixtures/ so the parsers are pinned to a live sample:

    ioreg -d2 -c IOPlatformExpertDevice
    system_profiler SPHardwareDataType

SammyMBPro-Sammy and MBP-van-pim-pim are the two Macs that currently submit
without a usable serial.
