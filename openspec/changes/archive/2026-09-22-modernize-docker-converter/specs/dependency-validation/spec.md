## MODIFIED Requirements

### Requirement: Informational Warnings Only
CVE scanner dependency checks SHALL be informational, not mandatory.

#### Scenario: Missing CVE scanner is a warning, not an error
- **WHEN** CVE scanner dependency check fails
- **THEN** the system SHALL display the message as "INFO:" or "WARNING:"
- **AND** SHALL NOT add the CVE scanner to MISSING_DEPS array
- **AND** SHALL NOT prevent audit from continuing
- **AND** deps_missing check SHALL pass

#### Scenario: Required dependencies still enforced
- **WHEN** required dependencies (lynis, fastfetch, jq, curl, tar, sed) are missing
- **THEN** the system SHALL add them to MISSING_DEPS array
- **AND** SHALL call deps_missing which exits with error
- **AND** SHALL prevent audit from starting

#### Scenario: Converter dependency depends on converter mode
- **WHEN** `USE_DOCKER_CONVERTER=true` and `docker` is missing
- **THEN** the system SHALL add `docker` to MISSING_DEPS array
- **AND** SHALL NOT require `python3`

#### Scenario: Docker is not required in the default converter mode
- **WHEN** `USE_DOCKER_CONVERTER` is unset or `false` and `python3` is missing
- **THEN** the system SHALL add `python3` to MISSING_DEPS array
- **AND** SHALL NOT add `docker` to MISSING_DEPS array
