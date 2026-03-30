## ADDED Requirements

### Requirement: Parse HardeningKitty CSV output
The system SHALL parse the HardeningKitty CSV file (hardeningkitty.csv) to extract security findings for compliance reporting and action list generation.

#### Scenario: CSV parsing with Import-Csv
- **WHEN** hardeningkitty.csv exists in the report directory
- **THEN** system uses PowerShell Import-Csv to load the CSV into objects with properties: ID, Category, Name, Severity, Result, Recommended, TestResult, SeverityFinding

#### Scenario: CSV file not found or empty
- **WHEN** hardeningkitty.csv does not exist or is empty
- **THEN** system reports "HardeningKitty data not available" in compliance report and skips action list generation

### Requirement: Identify failed HardeningKitty checks
The system SHALL identify all HardeningKitty findings where the Result value differs from the Recommended value, indicating a security configuration issue.

#### Scenario: Comparing Result and Recommended fields
- **WHEN** processing each row from hardeningkitty.csv
- **THEN** system flags the finding as failed if Result != Recommended (string comparison, handling empty values)

#### Scenario: No failed checks
- **WHEN** all HardeningKitty findings have Result == Recommended
- **THEN** system reports "All HardeningKitty checks passed" with total check count

### Requirement: Categorize findings by severity
The system SHALL group failed HardeningKitty findings by their Severity column (High, Medium, Low) for prioritized action reporting.

#### Scenario: Severity-based grouping
- **WHEN** failed findings are identified
- **THEN** system creates three groups: High severity findings, Medium severity findings, and Low severity findings

#### Scenario: Severity value missing or empty
- **WHEN** a finding has empty or null Severity field
- **THEN** system treats the finding as "Low" severity by default

### Requirement: Calculate HardeningKitty summary statistics
The system SHALL calculate summary statistics from HardeningKitty results including total checks, passed checks, failed checks by severity, and unique categories.

#### Scenario: Summary statistics calculation
- **WHEN** hardeningkitty.csv is parsed
- **THEN** system counts total rows, checks where Result==Recommended (passed), checks where Result!=Recommended grouped by Severity (failed), and distinct Category values

#### Scenario: Statistics in compliance report
- **WHEN** compliance report is generated
- **THEN** HardeningKitty section shows: "Total Checks: X, Passed: Y, Failed: Z (High: A, Medium: B, Low: C), Categories: N"

### Requirement: Generate detailed action list from findings
The system SHALL generate a detailed action list in actions.md with each failed HardeningKitty finding showing ID, Category, Name, Severity, Current Result, and Recommended Value.

#### Scenario: Action list formatting
- **WHEN** failed findings are processed for actions.md
- **THEN** each finding is formatted as: "**[ID]** Category: Name - Current: Result, Recommended: Recommended (Severity severity)"

#### Scenario: Grouped by severity in actions report
- **WHEN** actions.md is generated
- **THEN** findings are organized into sections: "## High Severity Issues", "## Medium Severity Issues", "## Low Severity Issues"

### Requirement: Link findings to ISO27001 controls
The system SHALL map HardeningKitty Category values to relevant ISO27001 control areas (Access Control, Cryptography, System Audit, etc.) in the compliance report.

#### Scenario: Category to ISO27001 mapping
- **WHEN** processing HardeningKitty findings by Category
- **THEN** system maps categories like "Account Policies" → "A.9 Access Control", "Windows Firewall" → "A.13 Network Security", "Microsoft Defender Antivirus" → "A.12 Malware Protection"

#### Scenario: Unknown category mapping
- **WHEN** a HardeningKitty Category doesn't match known ISO27001 mapping
- **THEN** system classifies it under "General Security Configuration"

### Requirement: Include HardeningKitty configuration details in compliance report
The system SHALL include a summary of HardeningKitty findings in the compliance report showing total checks, pass/fail breakdown, and key failed categories.

#### Scenario: HardeningKitty summary section
- **WHEN** compliance.md is generated
- **THEN** includes "## HardeningKitty Security Audit" section with statistics and top 5 categories with most failures

#### Scenario: Reference to detailed actions report
- **WHEN** compliance report includes HardeningKitty summary
- **THEN** includes text: "See honeybadger-{user}-{date}-actions.md for detailed remediation steps"
