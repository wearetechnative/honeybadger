## ADDED Requirements

### Requirement: Generate actions report file
The system SHALL generate an actions report file named `honeybadger-{username}-{date}-actions.md` containing all Lynis findings organized by severity level.

#### Scenario: Actions report created
- **WHEN** `check-output` command processes Lynis findings
- **THEN** a markdown file is created at `honeybadger-{username}-{date}-actions.md`

#### Scenario: Report includes metadata
- **WHEN** actions report is generated
- **THEN** the header includes scan date, hostname, and total action counts by severity

### Requirement: Organize findings by severity
The system SHALL structure the actions report with separate sections for each severity level in descending order: CRITICAL, HIGH, MEDIUM, LOW.

#### Scenario: CRITICAL section
- **WHEN** CRITICAL severity findings exist
- **THEN** the report includes "🔴 CRITICAL (fix binnen 1 week)" section listing all critical findings

#### Scenario: HIGH section
- **WHEN** HIGH severity findings exist
- **THEN** the report includes "🟠 HIGH (fix binnen 1 week)" section listing all high findings

#### Scenario: MEDIUM section
- **WHEN** MEDIUM severity findings exist
- **THEN** the report includes "🟡 MEDIUM (fix binnen 1 maand)" section listing all medium findings

#### Scenario: LOW section
- **WHEN** LOW severity findings exist
- **THEN** the report includes "🟢 LOW (best effort)" section listing all low findings

#### Scenario: No findings at severity level
- **WHEN** no findings exist for a severity level
- **THEN** that severity section is omitted from the report

### Requirement: Display finding details
The system SHALL display each finding with its test ID, description, and severity label.

#### Scenario: Finding entry format
- **WHEN** rendering a finding in the actions report
- **THEN** it includes a heading with test ID (e.g., "### PKGS-7392: Vulnerable software packages detected") followed by the description

#### Scenario: Include severity badge
- **WHEN** displaying a finding
- **THEN** the finding includes its severity classification for clarity

### Requirement: Show remediation timeline
The system SHALL include deadline information for each severity level section based on ISO27001 compliance requirements.

#### Scenario: CRITICAL and HIGH deadlines
- **WHEN** displaying CRITICAL or HIGH severity sections
- **THEN** the section header includes "(fix binnen 1 week)" text

#### Scenario: MEDIUM deadline
- **WHEN** displaying MEDIUM severity section
- **THEN** the section header includes "(fix binnen 1 maand)" text

#### Scenario: LOW deadline
- **WHEN** displaying LOW severity section
- **THEN** the section header includes "(best effort)" text

### Requirement: Include summary statistics
The system SHALL include a summary line showing total count and breakdown by severity in the report header.

#### Scenario: Summary with multiple severities
- **WHEN** findings exist across multiple severity levels
- **THEN** the header shows "**Totaal:** 23 acties (3 Critical, 5 High, 12 Medium, 3 Low)"

#### Scenario: Summary with single severity
- **WHEN** findings exist only at one severity level
- **THEN** the header shows total count and only the non-zero severity counts

### Requirement: Link to compliance report
The system SHALL include a footer referencing the companion compliance report for overall status context.

#### Scenario: Report footer
- **WHEN** actions report is generated
- **THEN** the footer includes "*Zie compliance report voor overall status*" or similar reference text

### Requirement: Handle empty findings
The system SHALL generate a meaningful message when no Lynis warnings or suggestions are found.

#### Scenario: No findings
- **WHEN** Lynis report contains zero warnings and zero suggestions
- **THEN** the actions report shows "✅ Geen security findings. Systeem is goed geconfigureerd!" message

### Requirement: Preserve finding order
The system SHALL preserve the original order of findings within each severity section as they appear in the Lynis report.

#### Scenario: Multiple findings same severity
- **WHEN** multiple findings have the same severity classification
- **THEN** they appear in the same order as they were listed in `lynis-report.json`

### Requirement: Use markdown formatting
The system SHALL use proper markdown formatting with headers, emoji icons, and code blocks where appropriate for readability.

#### Scenario: Markdown structure
- **WHEN** generating the actions report
- **THEN** it uses markdown heading levels (##, ###), emoji icons (🔴, 🟠, 🟡, 🟢), and proper spacing for visual clarity
