## REMOVED Requirements

### Requirement: Report Type Naming

**Reason**: The client no longer names report types at all. Submission goes
through the archive, and the server derives each type from the file name inside
it. The requirement existed to keep two paths in step with one another; there is
one path now.

**Migration**: The file names the audit writes - `fastfetch.json` and
`lynis-report.json` - are what the server matches on, and that is covered by
"Submit audit results to the collection server" below.

### Requirement: Missing Report Handling

**Reason**: Both scenarios describe the per-report path: a missing
`fastfetch.json` in an output directory, and a partial run where some reports
reached the server and others did not. Neither can occur when the unit of
submission is one archive.

**Migration**: Replaced by "Missing Archive Handling" below, which covers the
cases that do occur - no archive found, and a named archive that is not there.

## MODIFIED Requirements

### Requirement: Submission Result Reporting
The client SHALL report what the server said about a submission, so an operator
can act on a rejection without reproducing it by hand.

#### Scenario: Server rejects a submission
- **WHEN** the server answers with a 4xx status
- **THEN** the client SHALL print the status code and the server's response body
- **AND** SHALL NOT retry

#### Scenario: Server stores a submission it could not fully resolve
- **WHEN** the server answers 207
- **THEN** the client SHALL treat the submission as successful
- **AND** SHALL name it a partial submission in its output
- **AND** SHALL NOT retry

#### Scenario: Transient server or network failure
- **WHEN** the server answers with a 5xx status or the request fails to complete
- **THEN** the client SHALL retry with exponential backoff up to the configured attempt count

## ADDED Requirements

### Requirement: Submit audit results to the collection server

The client SHALL submit audit results as the tar archive, so that the hardware
serial travels with them and the server can attribute the submission to an asset.

#### Scenario: Submit sends the archive
- **WHEN** an operator runs `./RUNME.sh submit`
- **THEN** the most recent archive SHALL be submitted to `SERVER_URL/submit-tar`

#### Scenario: Explicit archive
- **WHEN** an operator runs `./RUNME.sh submit <file>`
- **THEN** that archive SHALL be submitted

#### Scenario: Serial travels with the submission
- **WHEN** an archive is submitted
- **THEN** it SHALL carry `hardware-serial.txt`, so the server can resolve the asset

#### Scenario: Report types come from the archive
- **WHEN** an archive is submitted
- **THEN** the client SHALL name no report types; the server derives them from
  the file names inside the archive

#### Scenario: Per-report submission is gone
- **WHEN** an operator looks for a way to submit individual reports
- **THEN** there SHALL be none; that path submitted to an endpoint with no
  concept of a hardware serial, so its submissions could not be attributed to
  an asset

### Requirement: Missing Archive Handling

The client SHALL distinguish a submission that could not be made from one that
was made, and SHALL NOT report a submission that never happened as a success.

#### Scenario: No archive found
- **WHEN** `submit` runs and no archive can be found
- **THEN** it SHALL report that none was found
- **AND** SHALL name the command that produces one

#### Scenario: Named archive does not exist
- **WHEN** `submit` is given a path that is not a file
- **THEN** it SHALL fail and name the path it was given

#### Scenario: Submission did not reach the server
- **WHEN** the archive could not be submitted
- **THEN** `submit` SHALL exit non-zero

### Requirement: Keep submit-tar working as a deprecated alias

`submit-tar` SHALL keep working and SHALL say it is deprecated, so that
scheduled jobs still calling it do not fail.

#### Scenario: Alias still submits
- **WHEN** an operator or a scheduled job runs `./RUNME.sh submit-tar`
- **THEN** the archive SHALL be submitted exactly as `submit` would

#### Scenario: Alias warns
- **WHEN** `submit-tar` runs
- **THEN** it SHALL report that the command is deprecated and name `submit`

#### Scenario: Exit code unchanged
- **WHEN** `submit-tar` runs
- **THEN** it SHALL exit with the same code `submit` would for the same archive
