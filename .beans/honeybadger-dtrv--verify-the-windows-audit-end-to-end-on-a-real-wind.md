---
# honeybadger-dtrv
title: Verify the Windows audit end-to-end on a real Windows machine
status: todo
type: task
priority: high
created_at: 2026-09-18T09:00:03Z
updated_at: 2026-09-18T09:00:03Z
parent: honeybadger-k80g
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
