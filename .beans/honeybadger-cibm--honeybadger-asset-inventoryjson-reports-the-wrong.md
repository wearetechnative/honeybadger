---
# honeybadger-cibm
title: 'honeybadger: asset-inventory.json reports the wrong username for hyphenated hostnames'
status: completed
type: bug
priority: high
tags:
    - honeybadger
    - iso27001
created_at: 2026-09-16T09:26:07Z
updated_at: 2026-09-16T11:42:26Z
---

`asset-inventory.json` reports a username that does not exist on the machine
when the hostname contains a hyphen. `asset-inventory.txt` gets it right, so the
two files disagree - and a comment in the code asserts they cannot.

## The cause

`generate_xlsx_asset_row_report` recovers the username from the output
directory name:

    if [[ "$dirname" =~ output-([^-]+)-([^-]+)-(.+)$ ]]; then
        username="${BASH_REMATCH[2]}"

`[^-]+` cannot span a hyphen, so a hyphenated hostname shifts the groups:

    output-lobos-wtoorren-15-09-2026                  -> wtoorren   correct
    output-technative-casper-casper-26-03-2026        -> casper     correct by luck
    output-hb-ubuntu-test-hbtest-16-09-2026           -> ubuntu     wrong, is hbtest
    output-pankhuri-prakash-IdeaPad-5-14ARE05-root-…  -> prakash    wrong, is root

The second case is right only because the hostname's last segment happens to
equal the username. The third names a user that does not exist on the box.

Hyphenated hostnames are the norm, not the exception - four of the systems on
compute2 have one.

## Why it matters more than a display glitch

The emitter's own comment reads:

    # The same determinations, serialised for the collection server. Emitted
    # here rather than derived again, so the two cannot disagree.

They do disagree. `asset-inventory.txt` takes the owner from the audit data and
is correct; the JSON takes it from the directory name and is not. The JSON is
the file the collection server reads, so the wrong one wins.

It also misnames the report: `honeybadger-ubuntu-test-hbtest-…-xlsx.md`.

## Found by

A honeybadger audit on Ubuntu 24.04 in a QEMU VM, hostname `hb-ubuntu-test`,
user `hbtest`. The JSON said `ubuntu`.

## To fix

The directory name is a lossy encoding of three values with an ambiguous
separator; parsing it back cannot be made reliable by a better regex. Take the
username from the same place `asset-inventory.txt` does - the audit data -
rather than from the path.

The date suffix has a fixed shape (`DD-MM-YYYY`) and can be anchored from the
right, which makes the remainder recoverable if the path really must be parsed.
But the audit already knows who ran it, so reading it back out of a filename is
solving a problem that need not exist.

Add a test over the real directory names on compute2, including
`pankhuri-prakash-IdeaPad-5-14ARE05-root`.

## Reproduced independently on Arch

Acceptance test for `honeybadger-ck4l`, stock Arch cloud image:

    output-hb-arch-test-hbtest-16-09-2026
      -> hostname=hb  username=arch  date=test-hbtest-16-09-2026

The real user is `hbtest`. `asset-inventory.json` claims `"username": "arch"`;
`fastfetch.json` has it right, so the two disagree within one submission.

Two platforms, two different hostnames, the same corruption. Any hyphenated
hostname hits it, which is most real fleet hosts - so production submissions are
very likely already carrying wrong usernames today.

`identity.hostname` survives only by accident: it comes from
`lynis-report.json`, not from this regex.

## Summary of Changes

Fixed in OpenSpec change `username-from-audit-data`, archived as
`openspec/changes/archive/2026-09-16-username-from-audit-data`.

### The username is no longer decoded from the path

`RUNME.sh` already runs fastfetch as the invoking user for exactly this
purpose - `sudo -u "${SUDO_USER:-$(whoami)}" fastfetch` - so
`fastfetch.json`'s `.user` is the value the directory name was built from,
recorded before the encoding lost it. It is not a second opinion; it is the
original, and it is what `asset-inventory.txt` has been reading all along.

`hb_audit_username()` reads `fastfetch.json`, then `neofetch.json`, then
`neofetch.txt`, then the directory name, and returns non-zero printing nothing
when no source answers. `generate_asset_inventory()` and the JSON emitter now
both call it, so the two files agree by construction rather than by comment.

### The fallback parse, corrected

`hb_parse_output_dirname()` anchors on the `DD-MM-YYYY` suffix and takes the
last hyphen-free segment before it as the username:

    ^output-(.+)-([^-]+)-([0-9]{2}-[0-9]{2}-[0-9]{4})$

Right for all eight real directory names, including
`output-pankhuri-prakash-IdeaPad-5-14ARE05-root-02-04-2026` and
`output-MacBook-Pro-van-Sebastiaan-basanneveld-20-04-2026`. Still wrong for a
username containing a hyphen, which is why it is the last resort rather than
the answer.

### Report names

`hb_report_basename()` replaces three copies of the old regex. The date was
corrupted too - `output-technative-casper-casper-26-03-2026` gave the right
username by luck but the date `casper-26-03-2026`, so even the "correct by
luck" case misnamed its reports.

### Demonstrated on real data in this repository

`output-mbp-van-pim-pim-07-04-2026` holds `neofetch.json` saying `pim` and an
`asset-inventory.txt` saying `pim`. The old regex gave `van` and would name the
report `honeybadger-van-pim-pim-07-04-2026-actions.md` - which is the file
sitting in the repository root. Running `check-output` over that directory now
produces `honeybadger-pim-07-04-2026-{compliance,actions,xlsx}.md`, and all four
outputs agree:

    asset-inventory.json  identity.username  pim
    asset-inventory.txt   Owner / User       pim
    compliance report     Eigenaar           pim
    xlsx report           scan-username      pim

`identity.hostname` stayed `mbp-van-pim` throughout - it comes from
`lynis-report.json`, which is why it was never affected.

### Tests

`tests/test_audit_identity.sh`, 51 assertions: every real directory name this
repository holds plus both acceptance-test hosts, a username containing a
hyphen, the fetch-file precedence order, the failure paths, report naming and
its fallback, and an assertion that the txt and the json name the same user. A
guard test fails the suite if the hyphen-blind regex returns - verified by
reintroducing it and watching the suite fail. Full suite: 9 files, passing.

### Also fixed

`_write_asset_inventory_json()` referenced `$thisdir`, which the library never
sets - exposed by the new tests running under `set -u`. Now `${thisdir:-.}`.
shellcheck over `lib/_library`: four fewer SC2155 and the SC2154 gone, no new
findings.
