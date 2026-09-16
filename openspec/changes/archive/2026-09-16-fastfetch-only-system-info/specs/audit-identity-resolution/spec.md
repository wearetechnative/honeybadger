## REMOVED Requirements

### Requirement: Username comes from the audit data

**Reason**: Its "Older archives still read back" scenario took the username from
`neofetch.json` or `neofetch.txt` when `fastfetch.json` was absent. Such a
directory is now refused for missing system information before the username is
ever needed, so the scenario describes a path that cannot be reached. Restated
as "Username comes from the recorded fetch data", which is the same requirement
without it.

**Migration**: None for current output directories. An archive predating the
fastfetch migration is re-audited rather than re-read.

## ADDED Requirements

### Requirement: Username comes from the recorded fetch data

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

#### Scenario: Retired formats are not consulted
- **WHEN** an output directory has no `fastfetch.json` but has `neofetch.json`
  or `neofetch.txt`
- **THEN** the username is not taken from those files

#### Scenario: No source answers
- **WHEN** no recorded source and no parsable directory name yields a username
- **THEN** the resolver reports that it could not determine one, rather than
  returning a default that looks like a name
