---
# honeybadger-ef74
title: 'Windows: replace neofetch with fastfetch and emit fastfetch.json'
status: completed
type: task
priority: high
created_at: 2026-09-18T08:40:27Z
updated_at: 2026-09-18T09:01:00Z
parent: honeybadger-k80g
---

AUDIT.ps1:132-150 installs and runs neofetch, writing neofetch.txt - ASCII art around a handful of values. The decision recorded in honeybadger-1pyf is that honeybadger and badgersbay read fastfetch.json only, with no fallback to a legacy format, and Windows was explicitly left out of that change.

Run fastfetch with a Windows config shipped beside the Linux one and write fastfetch.json in the same flat snake_case shape RUNME.sh produces, so hb_audit_username and every other consumer reads a Windows archive the same way it reads a Linux one.


## Summary of Changes

AUDIT.ps1 runs fastfetch with lib/fastfetch-config-windows.jsonc and writes
fastfetch.json through the module parser, in the flat snake_case shape RUNME.sh
produces. The neofetch install, invocation and neofetch.txt are gone, and so is
the Win32_OperatingSystem fallback: a file with some keys missing is
indistinguishable to a consumer from a machine where those values could not be
read, so the audit stops and names the dependency instead. The compliance
report's OS version is the fastfetch os value.

The Windows config is separate from the Linux one because the latter's command
modules run /etc/os-release, uname, apt, dnf, pacman and nixos-rebuild. The two
differ in how they get values and agree on what the values are called.
