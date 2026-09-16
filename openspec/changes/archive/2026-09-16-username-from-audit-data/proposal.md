## Why

`asset-inventory.json` reports a username that does not exist on the audited
machine whenever the hostname contains a hyphen. `asset-inventory.txt` reports
the right one, so the two files disagree - and the emitter's own comment says
they cannot:

    # The same determinations, serialised for the collection server. Emitted
    # here rather than derived again, so the two cannot disagree.

Three report generators recover the username and the date by parsing them back
out of the output directory's name:

    if [[ "$dirname" =~ output-([^-]+)-([^-]+)-(.+)$ ]]; then
        local hostname="${BASH_REMATCH[1]}"
        local username="${BASH_REMATCH[2]}"
        local datepart="${BASH_REMATCH[3]}"

`[^-]+` cannot span a hyphen, so a hyphenated hostname shifts every group. Run
against the directory names this repository actually contains, plus the two
acceptance-test hosts:

    output-lobos-wtoorren-15-09-2026              user=wtoorren  date=15-09-2026
    output-Jeroen-jeroen-14-09-2026               user=jeroen    date=14-09-2026
    output-technative-casper-casper-26-03-2026    user=casper    date=casper-26-03-2026
    output-mbp-van-pim-pim-07-04-2026             user=van       date=pim-pim-07-04-2026
    output-hb-ubuntu-test-hbtest-16-09-2026       user=ubuntu    date=test-hbtest-16-09-2026
    output-hb-arch-test-hbtest-16-09-2026         user=arch      date=test-hbtest-16-09-2026
    output-pankhuri-prakash-IdeaPad-5-14ARE05-root-02-04-2026
                                                  user=prakash   date=IdeaPad-5-14ARE05-root-02-04-2026
    output-MacBook-Pro-van-Sebastiaan-basanneveld-20-04-2026
                                                  user=Pro       date=van-Sebastiaan-basanneveld-20-04-2026

Two of eight are right. `technative-casper` gets the username right only
because the hostname's last segment happens to equal the username, and its date
is wrong anyway.

The damage is already in this repository. `output-mbp-van-pim-pim-07-04-2026`
holds `neofetch.json` saying `"user": "pim"` and an `asset-inventory.txt` saying
`Owner / User | pim`, and next to it sit the reports the same run produced:

    honeybadger-van-pim-pim-07-04-2026-actions.md
    honeybadger-Pro-van-Sebastiaan-basanneveld-20-04-2026-compliance.md
    honeybadger-prakash-IdeaPad-5-14ARE05-root-02-04-2026-actions.md

`asset-inventory.json` is the file the collection server reads, so the wrong
value is the one that wins. Hyphenated hostnames are the norm rather than the
exception, so production submissions are very likely already carrying wrong
usernames.

`identity.hostname` survives only by accident: it comes from
`lynis-report.json`, not from this regex.

## What Changes

- **Take the username from the audit data, not from the path.** `RUNME.sh`
  already runs `fastfetch` as the invoking user for exactly this reason
  (`sudo -u "${SUDO_USER:-$(whoami)}" fastfetch`), so `fastfetch.json`'s `.user`
  is the same value the directory name was built from - before the encoding
  lost it. `asset-inventory.txt` reads that field today and is correct.
- **Resolve it in one place.** `hb_audit_username()` becomes the single source
  for every consumer, so `asset-inventory.txt` and `asset-inventory.json`
  cannot disagree by construction rather than by comment.
- **Anchor the fallback on the date.** For an archive with no fetch file, the
  directory name is still parsed - but anchored on the `DD-MM-YYYY` suffix from
  the right, which makes the remaining fields recoverable.
- **Fix the report names too.** `honeybadger-{username}-{date}-{kind}.md` was
  built from the same broken groups, which is why the files above are named as
  they are.

## Capabilities

### New Capabilities
- `audit-identity-resolution`: where the username and the run's date come from,
  in what order, and what happens when none of the sources answer

### Modified Capabilities
- `asset-inventory-json`: `identity.username` is the audit's determination and
  agrees with `asset-inventory.txt`

## Impact

- Submissions from any host with a hyphenated hostname stop carrying a username
  that does not exist on the machine.
- Report filenames change for those hosts - from
  `honeybadger-van-pim-pim-07-04-2026-actions.md` to
  `honeybadger-pim-07-04-2026-actions.md`. Hosts that were already correct are
  unaffected.
- Archives produced before this change are read back correctly: the date-anchored
  parse recovers what the old regex could not, and a fetch file overrides it.
- No new dependency. `fastfetch` is already required and already run for this.

## Non-goals

- Changing the output directory's name. Encoding three values with an ambiguous
  separator is what made this possible, but the name is what operators look for,
  what the tarball is called, and what the server has already stored. Reading
  the username from the audit data removes the need to decode it.
- Windows. `AUDIT.ps1` does not derive the username from a path.
