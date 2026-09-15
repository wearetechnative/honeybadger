## ADDED Requirements

### Requirement: Report Type Naming
The client SHALL name each submitted report after the tool that produced it, using the type names the collection server accepts, and the per-report and tar submission paths SHALL agree on those names.

#### Scenario: System information report type
- **WHEN** `submit` sends the system information report
- **THEN** it SHALL send `X-Report-Type: fastfetch`
- **AND** it SHALL read the report from `fastfetch.json` in the output directory
- **AND** it SHALL NOT send the retired type `neofetch`

#### Scenario: Hardening report type
- **WHEN** `submit` sends the hardening report
- **THEN** it SHALL send `X-Report-Type: lynis`
- **AND** it SHALL read the report from `lynis-report.json` in the output directory

#### Scenario: Both paths carry the same set of reports
- **WHEN** the same output directory is submitted by `submit` and by `submit-tar`
- **THEN** both paths SHALL deliver the system information report and the hardening report
- **AND** the report types the server records SHALL be the same for both paths

### Requirement: Missing Report Handling
The client SHALL distinguish a report that could not be submitted from one that was submitted, and SHALL NOT report a submission that never happened as a success.

#### Scenario: System information file absent
- **WHEN** `submit` runs against an output directory with no `fastfetch.json`
- **THEN** the system information report SHALL be counted as failed
- **AND** the summary SHALL name the file that was expected

#### Scenario: Not every report reached the server
- **WHEN** any report in the output directory could not be submitted
- **THEN** `submit` SHALL exit non-zero
- **AND** the summary SHALL list the reports that failed

### Requirement: Submission Result Reporting
The client SHALL report what the server said about a submission, so an operator can act on a rejection without reproducing it by hand.

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
