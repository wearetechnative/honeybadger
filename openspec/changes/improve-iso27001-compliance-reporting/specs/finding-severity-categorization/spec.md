## ADDED Requirements

### Requirement: System SHALL categorize Lynis findings by severity
The Lynis findings report SHALL group and display warnings and suggestions by severity level.

#### Scenario: Severity levels extracted from Lynis data
- **WHEN** processing lynis-report.json
- **THEN** the system SHALL examine the `.suggestion[]` array for severity fields
- **AND** SHALL categorize findings as: Critical, High, Medium, Low, or Unspecified

#### Scenario: Findings grouped by severity
- **WHEN** generating the warnings report
- **THEN** the system SHALL create separate sections for each severity level
- **AND** SHALL order sections from highest to lowest severity

### Requirement: Critical findings SHALL be prominently displayed
Critical and high-severity findings SHALL be clearly distinguished and displayed first in the report.

#### Scenario: Critical findings section
- **WHEN** Lynis report contains critical findings
- **THEN** the report SHALL include a "CRITICAL FINDINGS" section at the top
- **AND** SHALL use visual indicators (e.g., ❌, red styling in HTML)

#### Scenario: Critical findings count in summary
- **WHEN** generating the report summary
- **THEN** the system SHALL display count: "X critical, Y high, Z medium findings"
- **AND** SHALL make the critical count prominent

### Requirement: HTML report SHALL use color coding for severity
The HTML warnings report SHALL use distinct colors for different severity levels.

#### Scenario: Severity color scheme
- **WHEN** generating HTML report
- **THEN** critical findings SHALL use red styling (#dc3545)
- **AND** high findings SHALL use orange styling (#fd7e14)
- **AND** medium findings SHALL use yellow styling (#ffc107)
- **AND** low findings SHALL use blue or green styling

#### Scenario: Severity badges displayed
- **WHEN** displaying individual findings
- **THEN** each finding SHALL include a severity badge
- **AND** the badge SHALL show the severity level text
- **AND** SHALL use appropriate background color

### Requirement: System SHALL handle missing severity information
The system SHALL handle findings that do not have severity information gracefully.

#### Scenario: Unspecified severity
- **WHEN** a Lynis finding lacks severity information
- **THEN** the system SHALL categorize it as "Unspecified"
- **AND** SHALL display it in a separate "Other Findings" section
- **AND** SHALL NOT fail the report generation

### Requirement: Severity filtering SHALL be based on Lynis data structure
The severity categorization SHALL use the actual fields available in Lynis JSON output.

#### Scenario: Research Lynis JSON structure
- **WHEN** implementing severity filtering
- **THEN** the system SHALL examine actual lynis-report.json files
- **AND** SHALL identify which fields contain severity/priority information
- **AND** SHALL document the mapping in code comments

#### Scenario: Fallback if no severity field exists
- **WHEN** Lynis JSON does not provide severity information
- **THEN** the system SHALL implement heuristic-based categorization
- **AND** SHALL use keywords in warning text to infer severity
- **AND** SHALL document this as a limitation
