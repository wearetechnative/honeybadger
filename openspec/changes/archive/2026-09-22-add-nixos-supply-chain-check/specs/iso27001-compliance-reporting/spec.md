## ADDED Requirements

### Requirement: Include NixOS supply chain status in compliance checklist
The system SHALL add a "NixOS Supply Chain" row to the ISO27001 compliance checklist table when the OS is NixOS.

#### Scenario: NixOS system with secure supply chain
- **WHEN** OS is NixOS and nix-supply-chain-audit.txt shows "Result: PASS"
- **THEN** compliance checklist includes row "NixOS Supply Chain | ✅ | Secure (signatures enforced)"

#### Scenario: NixOS system with insecure supply chain
- **WHEN** OS is NixOS and nix-supply-chain-audit.txt shows "Result: FAIL"
- **THEN** compliance checklist includes row "NixOS Supply Chain | ❌ | Insecure" and issue is added to critical issues list

#### Scenario: Non-NixOS system
- **WHEN** OS is not NixOS
- **THEN** NixOS Supply Chain row is not included in compliance checklist

### Requirement: Mark insecure supply chain as CRITICAL
The system SHALL treat insecure NixOS supply chain (FAIL status) as a CRITICAL compliance issue requiring fix within 1 week.

#### Scenario: Supply chain fails audit
- **WHEN** NixOS supply chain audit returns FAIL
- **THEN** "Insecure NixOS supply chain" is added to critical_issues array

#### Scenario: Supply chain passes audit
- **WHEN** NixOS supply chain audit returns PASS
- **THEN** no critical issue is added for supply chain

### Requirement: Include supply chain details in system information
The system SHALL include NixOS supply chain audit details in the system information section when available.

#### Scenario: Audit file exists
- **WHEN** nix-supply-chain-audit.txt file exists in output directory
- **THEN** system information section includes "NixOS Supply Chain Audit" subsection with audit output

#### Scenario: Audit file missing
- **WHEN** nix-supply-chain-audit.txt does not exist
- **THEN** no NixOS supply chain section is added to system information

### Requirement: Include supply chain status in asset inventory
The system SHALL add "NixOS Supply Chain" field to asset inventory table for NixOS systems.

#### Scenario: NixOS system with audit results
- **WHEN** generating asset inventory for NixOS system with nix-audit results
- **THEN** table includes "NixOS Supply Chain | Secure (sigs enforced)" or "NixOS Supply Chain | Insecure"

#### Scenario: Non-NixOS system
- **WHEN** generating asset inventory for non-NixOS system
- **THEN** NixOS Supply Chain field is omitted from table
