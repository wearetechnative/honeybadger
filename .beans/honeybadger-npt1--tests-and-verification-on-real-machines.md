---
# honeybadger-npt1
title: Tests and verification on real machines
status: completed
type: task
priority: normal
tags:
    - honeybadger
created_at: 2026-09-15T21:16:30Z
updated_at: 2026-09-15T21:30:06Z
parent: honeybadger-ck4l
---

Unit tests for the validation function against the real values found on
compute2: `PF50L2MR`, `MP1Y69AC`, `FRANDGCPA5530200H9`, `Not available`,
`Mac OS X<TAB>`, `00000000`, empty, absent.

Test the Linux chain with each source stubbed in turn, asserting that later
steps are not reached when an earlier one succeeds.

Test the macOS parser against real `ioreg` and `system_profiler` output captured
from a Mac.

Manual verification, because this is exactly where it went wrong:

    NixOS without dmidecode in PATH    the technative-casper case
    Ubuntu or Debian
    Arch
    macOS                             compare with About This Mac
    a virtual machine                 must yield none-present

Tasks 5.1 to 5.4 and 6.1 to 6.5 in the OpenSpec change.

## Summary of Changes

A shell test suite was added under `tests/`, run with `./RUNME.sh run-tests`.
133 assertions across four files, all passing, plus shellcheck clean:

    test_serial_validation.sh    35  the real compute2 values and every placeholder
    test_serial_linux_chain.sh   33  each source stubbed in turn
    test_serial_macos.sh         25  both parsers and the macOS chain
    test_serial_reporting.sh     40  what is written, said and read back

`tests/lib.sh` holds the assertions plus `link_real_tools()`, which builds a
minimal PATH so a test can honestly assert "dmidecode is not installed" on a
machine that has it, and can exercise the NixOS branch on a machine that is not
NixOS. The library takes its inputs through `HB_*` overrides and PATH, so no
test touches the machine it runs on.

Manual verification:

    NixOS, dmidecode removed from PATH   PF50L2MR via sysfs:product_serial
    Debian 12 / Ubuntu 24.04 / Arch      same value, same source, same code path
    a VM-shaped DMI (placeholder+empty)  none-present, reported as such
    macOS                                NOT DONE - honeybadger-1lo9

The NixOS value matches `sudo cat /sys/class/dmi/id/product_serial`. The three
distributions were run as containers over the host DMI, with `dmidecode` absent
in all three - which is what "the same code path with no distribution-specific
handling" has to mean.
