## ADDED Requirements

### Requirement: System SHALL display Lynis hardening score in asset inventory
The asset inventory report SHALL extract and display the Lynis hardening score from the Lynis audit results.

#### Scenario: Hardening score extracted from Lynis report
- **WHEN** Lynis audit completes and generates lynis-report.json
- **THEN** the system SHALL read the `.hardening_index` field from the JSON
- **AND** SHALL include the score in the asset inventory report

#### Scenario: Hardening score displayed with format
- **WHEN** asset inventory is generated
- **THEN** the hardening score SHALL be displayed in format "X/100"
- **AND** SHALL be labeled as "Lynis Hardening Score"

#### Scenario: Hardening score shown with status indicator
- **WHEN** displaying the hardening score
- **THEN** the system SHALL include a status indicator:
  - 80-100: "Excellent"
  - 60-79: "Good"
  - 40-59: "Fair"
  - 0-39: "Poor"

### Requirement: System SHALL handle missing hardening score gracefully
The audit SHALL handle cases where Lynis does not provide a hardening score.

#### Scenario: Hardening score unavailable
- **WHEN** lynis-report.json does not contain `.hardening_index` field
- **THEN** the system SHALL display "Unknown" or "Not available"
- **AND** SHALL NOT fail the audit
- **AND** SHALL log a warning about missing score
