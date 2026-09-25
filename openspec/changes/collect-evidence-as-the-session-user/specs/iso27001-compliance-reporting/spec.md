## MODIFIED Requirements

### Requirement: Check firewall status
The system SHALL determine firewall status from evidence collected on the audited device: the
firewall evidence file written during the audit, and the `lynis-report.json` `firewall_active`
field. It SHALL NOT probe the firewall of the machine the evaluation runs on.

#### Scenario: Active ruleset collected during the audit
- **WHEN** `firewall-info.txt` records an active ruleset
- **THEN** the compliance report shows the firewall as ✅ and names the tool that holds the ruleset

#### Scenario: Firewall inactive
- **WHEN** `firewall-info.txt` records no active ruleset
- **AND** `lynis-report.json` contains `"firewall_active": "0"`
- **THEN** the compliance report shows the firewall as ❌ and marks this as CRITICAL

#### Scenario: Firewall active
- **WHEN** `lynis-report.json` contains `"firewall_active": "1"`
- **THEN** the compliance report shows the firewall as ✅

#### Scenario: Archive collected before firewall evidence existed
- **WHEN** the output directory contains no `firewall-info.txt`
- **AND** `lynis-report.json` contains `"firewall_active": "0"`
- **THEN** the firewall is reported as indeterminate (❓), not as failed
- **AND** the detail states that no firewall evidence was collected and Lynis alone does not
  recognise every ruleset

#### Scenario: Firewall evidence unavailable
- **WHEN** the output directory contains neither `firewall-info.txt` nor a readable
  `lynis-report.json`
- **THEN** the firewall is reported as indeterminate (❓) and it is not a blocker

#### Scenario: Evaluation does not touch the analysing machine
- **WHEN** `check-output` evaluates an output directory or archive
- **THEN** no firewall command is run on the machine performing the evaluation
- **AND** no privilege escalation is requested
