---
# honeybadger-5gmz
title: 'Linux: read the serial from sysfs, with dmidecode and nix as fallbacks'
status: completed
type: task
priority: high
tags:
    - honeybadger
created_at: 2026-09-15T21:16:29Z
updated_at: 2026-09-15T21:29:48Z
parent: honeybadger-ck4l
---

Replace the block at `RUNME.sh:171-175` with a chain that stops as soon as a
source yields a usable value:

    1. /sys/class/dmi/id/product_serial     root, no tool, no network
    2. /sys/class/dmi/id/board_serial       some vendors fill only this one
    3. dmidecode -s system-serial-number    if the tool happens to be present
    4. nix run nixpkgs#dmidecode            NixOS, last resort

Step 4 needs `--extra-experimental-features "nix-command flakes"` and the
network on first use, so it should only be reached when 1 through 3 yield
nothing.

Do NOT add `dmidecode` to `checkdeps` (RUNME.sh:33). That would abort the audit
on machines where sysfs works perfectly, which is most of them. The dependency
is the serial, not the tool that fetches it.

Tasks 1.1 to 1.6 in the OpenSpec change.

## Summary of Changes

`hb_collect_serial_linux()` replaces the block at `RUNME.sh:171-175`:

    1. /sys/class/dmi/id/product_serial   sysfs:product_serial
    2. /sys/class/dmi/id/board_serial     sysfs:board_serial
    3. dmidecode -s system-serial-number  dmidecode
    4. nix run nixpkgs#dmidecode          nix:dmidecode  (NixOS only)

Each step runs only when the previous produced nothing usable; the tests assert
that later steps are never invoked when an earlier one succeeds. `dmidecode` was
not added to `checkdeps`, and a test fails the build if anyone adds it.

Verified on the real hardware of this NixOS machine with dmidecode removed from
PATH (the technative-casper case): `PF50L2MR` via `sysfs:product_serial`,
matching `sudo cat /sys/class/dmi/id/product_serial`. The same code path was run
unchanged against Debian 12, Ubuntu 24.04 and Arch userlands over the host DMI,
with `dmidecode` absent in all three - same value, same source.
