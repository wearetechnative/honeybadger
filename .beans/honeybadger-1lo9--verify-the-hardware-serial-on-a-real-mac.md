---
# honeybadger-1lo9
title: Verify the hardware serial on a real Mac
status: todo
type: task
priority: high
created_at: 2026-09-15T21:29:30Z
updated_at: 2026-09-18T14:12:31Z
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


## Blocked: no Mac has run the current client

Checked on 2026-09-18 against the two macOS assets in the register,
`TARI-00017` (Sammy Kooti, `FVFFP1TPQ05N`) and `TARI-00030` (Bas Anneveld,
`FVFZR9LXL40Y`). Both have submitted and both matched their asset, which looks
like this task answering itself. It does not.

Both archives report `Honeybadger v0.4.1` in `honeybadger-info.txt` - the client
generation from before the serial work. Neither run exercised the chain this
task exists to verify.

`TARI-00030` is certain: its original archive carried `hardware-serial.txt`
containing `Not available` and a `neofetch.json`, and the files were edited by
hand before it was resubmitted. The serial in the stored record was typed, not
read.

`TARI-00017` is unresolved rather than proven. Its archive holds the right
serial, but v0.4.1 is the generation that writes the placeholder, and the
archive also carries `fastfetch.json` where that version writes
`neofetch.json` - so it was altered too. How the serial came to be correct is
not established.

That both archives are dated before the client was finished and both were
modified is the point: a submission matching its asset says the register is
right, not that the client can read a serial.

## What unblocks it

One Mac running the current client, from a clean checkout:

    git clone https://github.com/wearetechnative/honeybadger
    cd honeybadger && sudo ./RUNME.sh audit && sudo ./RUNME.sh submit

Then confirm `hardware-serial.txt` in the stored archive holds the machine's
serial and that `honeybadger-info.txt` reports the current version rather than
v0.4.1.

Beans has no `blocked` status, so this stays `todo` with the blocker written
down. What blocks it is an action by a person, not another bean, so there is
nothing to point `--blocked-by` at.
