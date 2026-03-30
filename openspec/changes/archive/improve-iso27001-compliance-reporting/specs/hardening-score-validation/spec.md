## ADDED Requirements

### Requirement: System SHALL validate hardening score meets minimum threshold
The audit SHALL check that the Lynis hardening score meets or exceeds the minimum required threshold of 65.

#### Scenario: Hardening score meets threshold
- **WHEN** Lynis hardening score is ≥65
- **THEN** the system SHALL mark the score as "COMPLIANT"
- **AND** SHALL display a pass indicator (✅) in the report

#### Scenario: Hardening score below threshold
- **WHEN** Lynis hardening score is <65
- **THEN** the system SHALL mark the score as "NON-COMPLIANT"
- **AND** SHALL display a fail indicator (❌) in the report
- **AND** SHALL include message "BELOW THRESHOLD (required: ≥65)"

### Requirement: System SHALL clearly indicate compliance status
The asset inventory SHALL prominently display whether the hardening score meets policy requirements.

#### Scenario: Compliant score display format
- **WHEN** hardening score is 78
- **THEN** the report SHALL display: "Lynis Hardening Score | 78/100 ✅ COMPLIANT (≥65)"

#### Scenario: Non-compliant score display format
- **WHEN** hardening score is 58
- **THEN** the report SHALL display: "Lynis Hardening Score | 58/100 ❌ NON-COMPLIANT (required: ≥65)"
- **AND** SHALL recommend "Hardening improvements needed"

### Requirement: Threshold value SHALL be configurable
The minimum hardening score threshold SHALL be defined as a constant that can be easily modified.

#### Scenario: Threshold defined in code
- **WHEN** implementing the validation
- **THEN** the threshold value SHALL be defined as a named constant (e.g., `MIN_HARDENING_SCORE=65`)
- **AND** SHALL be referenced by constant name, not hardcoded

#### Scenario: Threshold change requires minimal code modification
- **WHEN** policy changes require different threshold
- **THEN** modifying the constant value SHALL be sufficient
- **AND** SHALL NOT require changes to validation logic
