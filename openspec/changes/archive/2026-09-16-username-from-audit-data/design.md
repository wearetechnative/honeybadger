# Design

## Why a better regex is not the fix

`output-{hostname}-{user}-{date}` joins three values with `-` and lets all three
contain `-`. That is a lossy encoding: `output-a-b-c-01-01-2026` could be
hostname `a-b` user `c` or hostname `a` user `b-c`, and nothing in the string
says which. No pattern resolves it, because the information is not there.

What saves the common case is that the date has a fixed shape. Anchoring
`[0-9]{2}-[0-9]{2}-[0-9]{4}` at the end and taking the last hyphen-free segment
before it as the username leaves the whole remainder as the hostname:

    ^output-(.+)-([^-]+)-([0-9]{2}-[0-9]{2}-[0-9]{4})$

That is right for every directory name this repository contains, including
`output-pankhuri-prakash-IdeaPad-5-14ARE05-root-02-04-2026` and
`output-MacBook-Pro-van-Sebastiaan-basanneveld-20-04-2026`. It is still wrong
for a username containing a hyphen, and it always will be.

So the parse is the fallback, not the answer. The answer is not to decode a
value the audit already recorded.

## Where the username actually lives

`RUNME.sh` builds the directory name from `actual_user`:

    local actual_user="${SUDO_USER:-$(whoami)}"

and runs fastfetch as that same user, deliberately:

    # Run fastfetch as actual user (not root) to capture correct username
    sudo -u "${SUDO_USER:-$(whoami)}" fastfetch ...

So `fastfetch.json`'s `.user` is the value the directory name was built from,
recorded before the encoding lost it. It is not a second opinion; it is the
original. `generate_asset_inventory()` has been reading it all along, which is
why `asset-inventory.txt` is the file that is right.

## Resolution order

`hb_audit_username <output_dir>`:

| Order | Source                        | Why                                       |
|-------|-------------------------------|-------------------------------------------|
| 1     | `fastfetch.json` `.user`      | what the audit recorded, as the real user |
| 2     | `neofetch.json` `.user`       | same field, archives before the switch    |
| 3     | `neofetch.txt` `user@host`    | same value, before either was JSON        |
| 4     | directory name, date-anchored | archives with no fetch file at all        |

Steps 2 and 3 are the shapes `generate_asset_inventory()` already handles, kept
so older tarballs keep reading back. Step 4 exists only for an archive that has
none of them; it is the old behaviour, corrected.

The function prints the name and returns non-zero when no source answers, so
the caller decides what an unknown user means rather than being handed a
plausible-looking default.

## One resolver, not three

The three generators - compliance, actions, xlsx - each carried their own copy
of the regex, and `generate_asset_inventory()` carried its own username lookup.
Four implementations of two questions.

`hb_audit_username()` and `hb_parse_output_dirname()` replace all four.
`generate_asset_inventory()` uses the resolver too, so the agreement between
`asset-inventory.txt` and `asset-inventory.json` is structural: they call the
same function. The comment that claimed they could not disagree becomes true.

## The date

The date is only ever used to name a report. It comes from the same
date-anchored parse, because unlike the username the audit does not record the
run date anywhere else in a comparable form - `lynis-report.json` has
`report_datetime_start`, but in a different format and describing when Lynis
started rather than what the run was named.

When the directory name does not parse, the existing fallback shape is kept:
`honeybadger-{kind}-{today}.md`. That is what the three generators already did.

## What is deliberately not changed

`_write_asset_inventory_json()` still takes the hostname from
`lynis-report.json`. It was never derived from the directory name, which is why
`identity.hostname` was correct throughout, and there is no reason to route it
through the new resolver.

The directory name keeps its shape. It is what the operator looks for, what the
tarball is called and what the collection server has already stored. The
encoding is ambiguous, but nothing needs to decode it any more.

## Behaviour change to expect

Report filenames change on hosts with a hyphenated hostname:

    honeybadger-van-pim-pim-07-04-2026-actions.md
      -> honeybadger-pim-07-04-2026-actions.md

    honeybadger-prakash-IdeaPad-5-14ARE05-root-02-04-2026-actions.md
      -> honeybadger-root-02-04-2026-actions.md

This is the correction, not a side effect: those names were built from the same
shifted groups that produced the wrong `identity.username`. Hosts that were
already right keep the names they had.
