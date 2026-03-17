# Report Submission

## ADDED Requirements

### Requirement: Standalone Submit Command
The system SHALL provide a separate submit command independent of the audit function.

#### Scenario: Invoke submit command
- **WHEN** user runs `./RUNME.sh submit`
- **THEN** the system SHALL load configuration from config file
- **AND** SHALL auto-detect the most recent output-* directory
- **AND** SHALL submit all available reports from that directory

#### Scenario: Submit specific directory
- **WHEN** user runs `./RUNME.sh submit output-hostname-user-date`
- **THEN** the system SHALL submit reports from the specified directory
- **AND** SHALL validate directory exists before attempting submission

#### Scenario: Submit command is independent of audit
- **WHEN** audit command runs
- **THEN** the system SHALL NOT automatically submit reports
- **AND** users MUST explicitly run submit command to send reports to server

#### Scenario: Handle missing output directory
- **WHEN** submit command runs
- **AND** no output directory is specified
- **AND** no output-* directories exist
- **THEN** the system SHALL log error message
- **AND** SHALL exit with non-zero code

#### Scenario: Submission summary and exit code
- **WHEN** submit command completes
- **THEN** the system SHALL log summary of submissions
- **AND** SHALL exit with code 0 if at least one report submitted successfully
- **AND** SHALL exit with code 1 if all submissions failed

### Requirement: Configuration File Support
The system SHALL support configuration files for server submission settings.

#### Scenario: Load configuration from file
- **WHEN** the audit command runs
- **THEN** the system SHALL check for configuration files in order:
  1. `./.honeybadger.conf` (current directory)
  2. `~/.honeybadger.conf` (user home directory)
  3. `/etc/honeybadger.conf` (system-wide)
- **AND** SHALL use the first configuration file found
- **AND** SHALL use default values if no configuration file exists

#### Scenario: Parse configuration options
- **WHEN** a configuration file is loaded
- **THEN** the system SHALL parse key=value pairs
- **AND** SHALL support the following options:
  - `SERVER_ENABLED` (true/false)
  - `SERVER_URL` (URL string)
  - `SERVER_TIMEOUT` (seconds)
  - `SERVER_RETRY_COUNT` (integer)
  - `DRY_RUN` (true/false)
- **AND** SHALL use default values for missing options

#### Scenario: Default configuration values
- **WHEN** no configuration file is found or option is not set
- **THEN** the system SHALL use these defaults:
  - `SERVER_ENABLED=false`
  - `SERVER_URL=http://localhost:7123/`
  - `SERVER_TIMEOUT=30`
  - `SERVER_RETRY_COUNT=3`
  - `DRY_RUN=false`

### Requirement: HTTP Report Submission
The system SHALL submit JSON reports to honeybadger-server via HTTP POST.

#### Scenario: Submit report with proper headers
- **WHEN** server submission is enabled
- **AND** a JSON report file exists
- **THEN** the system SHALL send HTTP POST to configured server URL
- **AND** SHALL include header `Content-Type: application/json`
- **AND** SHALL include header `X-Hostname` with system hostname
- **AND** SHALL include header `X-Username` with original username (from SUDO_USER or whoami)
- **AND** SHALL include header `X-Report-Type` with report type (lynis, trivy, vulnix, or neofetch)
- **AND** SHALL send the JSON file content as request body

#### Scenario: Auto-detect system identity
- **WHEN** preparing report submission
- **THEN** the system SHALL detect hostname using `hostname -s`
- **AND** SHALL detect username using `${SUDO_USER:-$(whoami)}`
- **AND** SHALL use these values in HTTP headers

#### Scenario: Submit multiple report types
- **WHEN** audit completes and server submission is enabled
- **THEN** the system SHALL attempt to submit neofetch.json (if exists)
- **AND** SHALL attempt to submit lynis-report.json (if exists)
- **AND** SHALL attempt to submit vulnix.json (if exists on NixOS)
- **AND** SHALL attempt to submit trivy.json (if exists on other OS)
- **AND** SHALL log success or failure for each submission

#### Scenario: Handle successful submission
- **WHEN** server responds with HTTP 200
- **THEN** the system SHALL log success message with report type and hostname
- **AND** SHALL proceed to next report

#### Scenario: Handle client errors
- **WHEN** server responds with HTTP 400 (Bad Request)
- **THEN** the system SHALL log error message
- **AND** SHALL NOT retry the submission
- **AND** SHALL proceed to next report

#### Scenario: Handle server errors
- **WHEN** server responds with HTTP 500 or 502 or 503
- **THEN** the system SHALL retry the submission
- **AND** SHALL follow retry logic with exponential backoff

### Requirement: Retry Logic with Exponential Backoff
The system SHALL implement retry logic for network failures.

#### Scenario: Retry on network failure
- **WHEN** report submission fails due to connection refused or timeout
- **THEN** the system SHALL retry up to configured retry count (default 3)
- **AND** SHALL wait with exponential backoff between retries
- **AND** SHALL log each retry attempt with attempt number

#### Scenario: Exponential backoff delays
- **WHEN** retrying a failed submission
- **THEN** retry attempt 1 SHALL wait 1 second before retrying
- **AND** retry attempt 2 SHALL wait 2 seconds before retrying
- **AND** retry attempt 3 SHALL wait 4 seconds before retrying

#### Scenario: Give up after max retries
- **WHEN** max retry count is reached
- **AND** submission still fails
- **THEN** the system SHALL log final failure
- **AND** SHALL proceed to next report
- **AND** SHALL NOT fail the overall audit

### Requirement: Dry-Run Mode
The system SHALL support dry-run mode for testing without actual submission.

#### Scenario: Enable dry-run mode
- **WHEN** configuration has `DRY_RUN=true`
- **THEN** the system SHALL NOT send actual HTTP requests
- **AND** SHALL log what would be submitted
- **AND** SHALL display the curl command that would be executed
- **AND** SHALL return success without making network calls

#### Scenario: Dry-run logging output
- **WHEN** dry-run mode is enabled
- **THEN** the system SHALL log:
  - Report file being submitted
  - Server URL
  - HTTP headers (X-Hostname, X-Username, X-Report-Type)
  - Complete curl command
- **AND** SHALL prefix all log messages with "DRY-RUN:"

### Requirement: Graceful Failure Handling
Server submission failures SHALL NOT block the submit command from completing.

#### Scenario: Continue with remaining submissions on failure
- **WHEN** any report submission fails
- **THEN** the system SHALL log the failure
- **AND** SHALL continue with remaining report submissions
- **AND** SHALL NOT abort the submit command

#### Scenario: Submit command independent of audit
- **WHEN** audit command runs
- **THEN** the system SHALL NOT attempt any server submissions
- **AND** SHALL complete audit successfully with only local reports

#### Scenario: Log submission summary
- **WHEN** submit command completes
- **THEN** the system SHALL log summary of submission results
- **AND** SHALL show count of successful submissions
- **AND** SHALL show count of failed submissions
- **AND** SHALL list which report types succeeded/failed

### Requirement: Report Type Identification
The system SHALL correctly identify report type for each JSON file.

#### Scenario: Identify lynis report
- **WHEN** submitting lynis-report.json
- **THEN** X-Report-Type header SHALL be "lynis"

#### Scenario: Identify neofetch report
- **WHEN** submitting neofetch.json
- **THEN** X-Report-Type header SHALL be "neofetch"

#### Scenario: Identify vulnix report
- **WHEN** submitting vulnix.json
- **THEN** X-Report-Type header SHALL be "vulnix"

#### Scenario: Identify trivy report
- **WHEN** submitting trivy.json
- **THEN** X-Report-Type header SHALL be "trivy"

### Requirement: JSON File Existence Check
The system SHALL check if report files exist before attempting submission.

#### Scenario: Skip submission if file does not exist
- **WHEN** attempting to submit a report
- **AND** the report file does not exist
- **THEN** the system SHALL log informational message
- **AND** SHALL skip submission for that report
- **AND** SHALL proceed to next report
- **AND** SHALL NOT treat this as an error
