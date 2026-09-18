---
# honeybadger-dtrv
title: Verify the Windows audit end-to-end on a real Windows machine
status: todo
type: task
priority: high
created_at: 2026-09-18T09:00:03Z
updated_at: 2026-09-18T09:14:31Z
---

honeybadger-k80g brought the Windows client onto the shared archive and submission path, and everything that does not need Windows is covered by tests/Honeybadger.Tests.ps1 under pwsh. What is not covered is data collection itself: Get-CimInstance, Get-BitLockerVolume, Get-MpComputerStatus, the registry reads, the winget install of fastfetch, and tar.exe.

No Windows machine was reachable from the host this was implemented on, which is the same gap honeybadger-1lo9 records for macOS.

What is left to do:

- Run AUDIT.ps1 on Windows 11 as Administrator.
- Confirm fastfetch installs through winget when absent, and that the shipped Windows config produces the keys the Linux one does - fastfetch.json must carry user, hostname, os, host and kernel.
- Confirm hardware-serial.txt holds the BIOS serial and hardware-serial-source.txt names wmi:Win32_BIOS.
- Confirm asset-inventory.json is valid, carries platform windows, and that its disk_encryption, screen_lock, firewall and os_uptodate findings agree with the compliance report.
- Confirm the tar.gz is produced by tar.exe with output-<host>-<user>-<dd-MM-yyyy>/ inside.
- Submit it to a real badgersbay and confirm the asset resolves.

Elmas machine (LAPTOP-AC06CMEP) and Richard van Os are the two assets this unblocks.


## What is waiting on this

`badgersbay-n8g8` - bring Windows into the denominator - is blocked on this
verification and cannot be started without it.

`MANUAL_CLASSES = {'windows'}` in badgersbay keeps Elma Aker (TARI-00031), Linda
de Ridder (TARI-00029) and Richard van Os (TARI-00034) out of the round's
denominator, shown as `manual` with *client cannot submit yet*. That exception
comes off when this passes, and not before: removing it against a client that
turns out not to work moves three people into the denominator for a reason
nobody can act on.

Beans has no cross-repository links, so this note and the one in `badgersbay-n8g8`
are the whole of that dependency. If either is rewritten, the other stops
pointing anywhere.

## Two register values this settles as a side effect

Both currently rest on a single reading:

- `TARI-00031` carries `YD063JGA`, read once from `Win32_BIOS` on Elma's laptop,
  while the ISO tool still holds `AC06CMEP` - the suffix of her Windows hostname
  `LAPTOP-AC06CMEP`.
- `TARI-00034` carries `PF-4VBTLB` with the hyphen the ISO tool writes. That
  hyphen proved to be decoration on Wouter's machine (tool `PF-50L2MR`, machine
  `PF50L2MR`), and `normalise_serial()` does not strip separators.

So report what the machines actually write in `hardware-serial.txt`, whether or
not it matches. A submission landing as `serial_not_in_register` is a result
here, not a failure of this task.
