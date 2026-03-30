## ADDED Requirements

### Requirement: Classify findings by severity
The system SHALL classify each Lynis warning and suggestion into one of four severity levels: CRITICAL, HIGH, MEDIUM, or LOW based on market-standard security practices.

#### Scenario: Known critical test IDs
- **WHEN** a Lynis finding has test ID "PKGS-7392" (vulnerable packages)
- **THEN** the system classifies it as CRITICAL severity

#### Scenario: Warning with critical keywords
- **WHEN** a Lynis warning contains keywords "vulnerable", "unpatched", "outdated", "exposed", "no encryption", "no firewall", or "authentication failed"
- **THEN** the system classifies it as CRITICAL severity

#### Scenario: Warning without critical keywords
- **WHEN** a Lynis warning does not contain critical keywords
- **THEN** the system classifies it as HIGH severity

#### Scenario: Suggestion with high-priority keywords
- **WHEN** a Lynis suggestion contains keywords "kernel", "ssh", "remote", "permissions", "access control", "update", or "patch"
- **THEN** the system classifies it as HIGH severity

#### Scenario: Suggestion with low-priority keywords
- **WHEN** a Lynis suggestion contains keywords "consider", "optional", or "recommended"
- **THEN** the system classifies it as LOW severity

#### Scenario: Default suggestion classification
- **WHEN** a Lynis suggestion does not match critical, high, or low keyword patterns
- **THEN** the system classifies it as MEDIUM severity

### Requirement: Extract finding details
The system SHALL extract test ID, description, and type (warning vs suggestion) from `lynis-report.json` for each finding.

#### Scenario: Parse warnings array
- **WHEN** processing `lynis-report.json`
- **THEN** the system extracts all entries from the `"warning[]"` array with their test IDs and descriptions

#### Scenario: Parse suggestions array
- **WHEN** processing `lynis-report.json`
- **THEN** the system extracts all entries from the `"suggestion[]"` array with their test IDs and descriptions

### Requirement: Use case-insensitive keyword matching
The system SHALL perform case-insensitive matching when searching for severity classification keywords in finding descriptions.

#### Scenario: Mixed case keywords
- **WHEN** a finding description contains "No Firewall" or "NO FIREWALL" or "no firewall"
- **THEN** the system matches the "no firewall" critical keyword pattern and classifies as CRITICAL

### Requirement: Apply market-standard severity definitions
The system SHALL apply severity definitions aligned with ISO27001, NIST cybersecurity framework, and standard vulnerability management practices.

#### Scenario: CRITICAL definition
- **WHEN** classifying a finding as CRITICAL
- **THEN** it MUST represent an issue that poses immediate security risk requiring fix within 1 week (e.g., no encryption, vulnerable software, disabled firewall, authentication failures)

#### Scenario: HIGH definition
- **WHEN** classifying a finding as HIGH
- **THEN** it MUST represent a security-impacting issue requiring fix within 1 week (e.g., weak screen lock, outdated kernel, SSH hardening issues)

#### Scenario: MEDIUM definition
- **WHEN** classifying a finding as MEDIUM
- **THEN** it MUST represent configuration hardening or logging improvements requiring fix within 1 month

#### Scenario: LOW definition
- **WHEN** classifying a finding as LOW
- **THEN** it MUST represent optional hardening or monitoring improvements with best-effort timeline

### Requirement: Support multiple keyword matches
The system SHALL check all relevant keyword lists and apply the highest matching severity level when multiple patterns match.

#### Scenario: Multiple keyword category matches
- **WHEN** a finding description contains both "update" (HIGH) and "consider" (LOW) keywords
- **THEN** the system classifies it as HIGH severity (higher takes precedence)
