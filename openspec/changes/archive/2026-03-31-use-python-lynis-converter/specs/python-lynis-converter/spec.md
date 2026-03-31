## ADDED Requirements

### Requirement: Default audit uses Python converter
The `audit` command SHALL use `lib/lynis_report_converter.py` as the default method to convert Lynis reports to JSON.

#### Scenario: Audit runs with Python converter by default
- **WHEN** a user runs `./RUNME.sh audit` without any converter configuration
- **THEN** the system SHALL invoke `python3 lib/lynis_report_converter.py --input-path /var/log/lynis-report.dat --output-path <output-dir>/lynis-report.json`
- **AND** the output file SHALL contain valid JSON

#### Scenario: Python3 not available
- **WHEN** a user runs `./RUNME.sh audit` and `python3` is not installed
- **THEN** the system SHALL exit with an error indicating that `python3` is a required dependency

### Requirement: Docker converter as configurable fallback
The system SHALL support a `USE_DOCKER_CONVERTER` configuration option that, when set to `true`, uses the Docker-based Perl converter instead of the Python script.

#### Scenario: Docker mode enabled via config
- **WHEN** `USE_DOCKER_CONVERTER=true` is set in `honeybadger.conf`
- **AND** the user runs `./RUNME.sh audit`
- **THEN** the system SHALL use the Docker-based converter (existing behavior)
- **AND** the system SHALL check for `docker` as a dependency

#### Scenario: Docker mode disabled (default)
- **WHEN** `USE_DOCKER_CONVERTER` is not set or set to `false`
- **AND** the user runs `./RUNME.sh audit`
- **THEN** the system SHALL NOT require Docker
- **AND** the system SHALL NOT check for `docker` as a dependency

### Requirement: Config file documents converter option
The `.honeybadger.conf.example` file SHALL include the `USE_DOCKER_CONVERTER` option with a default value of `false` and a description.

#### Scenario: Example config contains converter option
- **WHEN** a user reads `.honeybadger.conf.example`
- **THEN** the file SHALL contain `USE_DOCKER_CONVERTER=false` with a comment explaining its purpose

### Requirement: Python converter script bundled in repo
The Python converter script SHALL be available at `lib/lynis_report_converter.py` within the repository.

#### Scenario: Script exists and is executable
- **WHEN** the repository is cloned
- **THEN** `lib/lynis_report_converter.py` SHALL exist
- **AND** it SHALL be executable
