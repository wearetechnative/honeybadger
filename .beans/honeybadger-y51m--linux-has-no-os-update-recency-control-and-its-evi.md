---
# honeybadger-y51m
title: Linux has no OS update-recency control, and its evidence is broken
status: todo
type: feature
priority: deferred
created_at: 2026-09-25T12:47:43Z
updated_at: 2026-09-25T12:47:43Z
---

The Windows client reports how recently updates were installed (compliant
under 14 days, warning at 14-30, non-compliant over 30). Linux has no such
control. It was planned in the iso27001-compliance-reporting-overhaul change
(tasks 1.7, 3.3, 6.11-6.13) and never built; that change was archived with
those tasks deferred to this bean.

What Linux does have is "OS Up-to-date" (check_os_uptodate(), xlsx column L):
whether the release is still supported. That is a different question - a
supported release can go months without an update being installed.

The evidence the control would read is not usable today.
lib/check-os-updates.sh writes os-update-history.txt during the audit, but
its version lists are out of date:

  - NixOS 26.05 (lobos, 25-09-2026): "Status: UNKNOWN VERSION,
    Compliance: NEEDS VERIFICATION", and it reports the channel as
    nixos-23.11, read from a channel list that a flake-based system does not
    use.
  - Debian 13 trixie (14-09-2026 scan): "UNKNOWN DEBIAN VERSION".

What building it would take:

  - Decide whether update recency is an ISO control on Linux at all, or
    whether "supported release" is enough. The Windows client treats it as one.
  - Make the collection establish the last update date without a version
    table: on NixOS the age of the current system generation, on Debian and
    Ubuntu the apt history log.
  - Add a three-state check (0 within 14 days, 1 over 30, 2 not established)
    and decide what 14-30 days means in a three-state world.
