# check-output Capability

## ADDED Requirements

### Requirement: Tar Archive Format Support
The `check-output` command SHALL accept both uncompressed tar archives (`.tar`) and gzip-compressed tar archives (`.tar.gz`) as input.

#### Scenario: Uncompressed tar file accepted
- **WHEN** user provides a `.tar` file as input
- **THEN** system extracts the archive successfully
- **AND** processes the contents identically to `.tar.gz` files

#### Scenario: Gzip-compressed tar file still works
- **WHEN** user provides a `.tar.gz` file as input
- **THEN** system extracts the archive successfully (existing behavior maintained)
- **AND** no regression in functionality

#### Scenario: Auto-detection tries multiple formats
- **WHEN** user provides a directory name that doesn't exist
- **THEN** system searches for matching `.tar.gz` file first
- **AND** if not found, searches for matching `.tar` file
- **AND** extracts whichever is found

#### Scenario: Appropriate extraction method used
- **WHEN** system processes `.tar.gz` file
- **THEN** system uses gzip decompression flags (`tar xzf`)
- **WHEN** system processes `.tar` file
- **THEN** system uses no compression flags (`tar xf`)

#### Scenario: Report filename handles both formats
- **WHEN** user runs `./RUNME.sh check-output honeybadger-user-09-02-2026.tar`
- **THEN** system creates `honeybadger-user-09-02-2026-report.txt`
- **WHEN** user runs `./RUNME.sh check-output honeybadger-user-09-02-2026.tar.gz`
- **THEN** system creates `honeybadger-user-09-02-2026-report.txt`

### Requirement: Help Text Accuracy
The `check-output` command help text SHALL accurately describe supported archive formats.

#### Scenario: Help shows both formats
- **WHEN** user runs `./RUNME.sh check-output` without arguments
- **THEN** usage text mentions both `.tar` and `.tar.gz` formats
- **AND** examples include both format types
