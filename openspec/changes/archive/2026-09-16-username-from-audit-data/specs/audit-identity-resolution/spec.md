## ADDED Requirements

### Requirement: Username comes from the audit data

The audit SHALL determine the username of the person who ran it from the data
the audit recorded, not by parsing it back out of the output directory's name.

#### Scenario: Fetch data is the source
- **WHEN** an output directory contains `fastfetch.json` with a `user` field
- **THEN** that value is the username for every report and for
  `asset-inventory.json`

#### Scenario: Hyphenated hostname does not affect the username
- **WHEN** the output directory is `output-hb-ubuntu-test-hbtest-16-09-2026`
  and the audit recorded the user as `hbtest`
- **THEN** the username is `hbtest`

#### Scenario: Username containing a hyphen
- **WHEN** the audit recorded a username that itself contains a hyphen
- **THEN** that username is reported in full

#### Scenario: Older archives still read back
- **WHEN** an output directory has no `fastfetch.json` but has `neofetch.json`
  or `neofetch.txt`
- **THEN** the username is taken from that file instead

#### Scenario: No source answers
- **WHEN** no recorded source and no parsable directory name yields a username
- **THEN** the resolver reports that it could not determine one, rather than
  returning a default that looks like a name

### Requirement: Directory name parsing anchored on the date

When the directory name must be parsed, the audit SHALL anchor on the
`DD-MM-YYYY` suffix and take the last hyphen-free segment before it as the
username, so that a hyphenated hostname does not shift the fields.

#### Scenario: Hostname with one hyphen
- **WHEN** the directory is `output-technative-casper-casper-26-03-2026`
- **THEN** the hostname is `technative-casper`, the username `casper` and the
  date `26-03-2026`

#### Scenario: Hostname with many hyphens
- **WHEN** the directory is
  `output-pankhuri-prakash-IdeaPad-5-14ARE05-root-02-04-2026`
- **THEN** the hostname is `pankhuri-prakash-IdeaPad-5-14ARE05`, the username
  `root` and the date `02-04-2026`

#### Scenario: Hostname without a hyphen
- **WHEN** the directory is `output-lobos-wtoorren-15-09-2026`
- **THEN** the hostname is `lobos`, the username `wtoorren` and the date
  `15-09-2026`

#### Scenario: Name that is not an audit output directory
- **WHEN** the directory name does not end in a `DD-MM-YYYY` suffix
- **THEN** the parse reports failure rather than returning partial fields

### Requirement: Reports named from the resolved identity

Report filenames SHALL use the resolved username and the run's date, so that a
report's name matches the machine it describes.

#### Scenario: Report named for the real user
- **WHEN** reports are generated from
  `output-mbp-van-pim-pim-07-04-2026`, whose audit data records the user `pim`
- **THEN** the reports are named `honeybadger-pim-07-04-2026-compliance.md`,
  `honeybadger-pim-07-04-2026-actions.md` and
  `honeybadger-pim-07-04-2026-xlsx.md`

#### Scenario: All three reports agree
- **WHEN** the compliance, actions and xlsx reports are generated from one
  output directory
- **THEN** all three filenames carry the same username and the same date

#### Scenario: Identity cannot be determined
- **WHEN** neither the audit data nor the directory name yields a username
- **THEN** the report falls back to `honeybadger-{kind}-{today}.md` rather than
  naming a user it does not know
