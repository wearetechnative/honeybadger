# check-output Capability

## ADDED Requirements

### Requirement: Report File Generation
The `check-output` command SHALL generate a text report file containing all terminal output produced during the analysis process.

#### Scenario: Report file created for directory input
- **WHEN** user runs `./RUNME.sh check-output output-user-09-02-2026`
- **THEN** system creates `honeybadger-user-09-02-2026-report.txt` in current directory
- **AND** report file contains all text displayed on terminal

#### Scenario: Report file created for tarball input
- **WHEN** user runs `./RUNME.sh check-output honeybadger-user-09-02-2026.tar.gz`
- **THEN** system creates `honeybadger-user-09-02-2026-report.txt` in current directory
- **AND** report file contains all text displayed on terminal

#### Scenario: Report file naming matches tarball convention
- **WHEN** check-output processes any valid input
- **THEN** report filename follows pattern `honeybadger-{username}-{date}-report.txt`
- **AND** filename is derived from the tarball or directory name

#### Scenario: Report file content completeness
- **WHEN** check-output generates report file
- **THEN** report SHALL include all processing messages (extraction, directory usage)
- **AND** report SHALL include release information update messages
- **AND** report SHALL include complete OS & kernel status analysis
- **AND** report SHALL include complete asset inventory table
- **AND** report SHALL include cleanup messages (when applicable)

### Requirement: User Notification
The `check-output` command SHALL inform the user about the generated report file location.

#### Scenario: Report location displayed on completion
- **WHEN** check-output completes successfully
- **THEN** system displays message indicating report file path
- **AND** message appears before script exit

#### Scenario: Report location displayed after cleanup
- **WHEN** check-output performs cleanup of extracted directory
- **THEN** report location message is still displayed
- **AND** report file remains accessible after cleanup

### Requirement: File Overwrite Handling
The system SHALL handle existing report files appropriately.

#### Scenario: Existing report file handling
- **WHEN** report file already exists at target path
- **THEN** system overwrites the existing file silently
- **OR** system prompts user for confirmation (consistent with existing behavior)
