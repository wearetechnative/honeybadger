---
# honeybadger-cibm
title: 'honeybadger: asset-inventory.json reports the wrong username for hyphenated hostnames'
status: todo
type: bug
priority: high
tags:
    - honeybadger
    - iso27001
created_at: 2026-09-16T09:26:07Z
updated_at: 2026-09-16T09:26:07Z
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
