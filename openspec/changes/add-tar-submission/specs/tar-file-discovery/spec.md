## ADDED Requirements

### Requirement: Auto-detect most recent tar file
The system SHALL automatically find and use the most recent tar archive when no file is specified.

#### Scenario: No tar file specified
- **WHEN** user runs `./RUNME.sh submit-tar` without arguments
- **THEN** system searches for files matching `honeybadger-*.tar.gz` and `honeybadger-*.tar`
- **THEN** system selects the most recently modified file
- **THEN** system logs "Found: honeybadger-hostname-user-20-03-2026.tar.gz"
- **THEN** system proceeds with upload of detected file

#### Scenario: No tar files found
- **WHEN** user runs `./RUNME.sh submit-tar` without arguments
- **THEN** system searches for tar files
- **THEN** system finds no matching files
- **THEN** system logs error "No tar files found. Run audit first or specify a tar file."
- **THEN** system shows usage example
- **THEN** system exits with non-zero code

#### Scenario: Multiple tar files available
- **WHEN** multiple tar files exist in directory
- **THEN** system selects the one with most recent modification time
- **THEN** system logs which file was selected

### Requirement: Accept explicit tar file parameter
The system SHALL accept an optional tar file path as command argument.

#### Scenario: Explicit tar.gz file specified
- **WHEN** user runs `./RUNME.sh submit-tar honeybadger-hostname-user-17-03-2026.tar.gz`
- **THEN** system uses the specified file
- **THEN** system does NOT search for other files

#### Scenario: Explicit tar file specified
- **WHEN** user runs `./RUNME.sh submit-tar honeybadger-hostname-user-17-03-2026.tar`
- **THEN** system uses the specified file
- **THEN** system uploads without decompression

#### Scenario: Relative or absolute path specified
- **WHEN** user specifies path like `./archives/honeybadger-old.tar.gz`
- **THEN** system uses the path as-is
- **THEN** system validates file exists at that location

### Requirement: Display usage on invalid arguments
The system SHALL show clear usage instructions when invoked incorrectly.

#### Scenario: Too many arguments
- **WHEN** user runs `./RUNME.sh submit-tar file1.tar file2.tar`
- **THEN** system shows usage message
- **THEN** system shows example: `./RUNME.sh submit-tar [tar-file]`
- **THEN** system exits with non-zero code

#### Scenario: Help requested
- **WHEN** user runs `./RUNME.sh submit-tar --help` or `./RUNME.sh submit-tar -h`
- **THEN** system shows usage message
- **THEN** system explains optional parameter
- **THEN** system shows examples for both auto-detect and explicit file
