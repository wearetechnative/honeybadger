## ADDED Requirements

### Requirement: Execute NixOS supply chain audit
The system SHALL execute PKGS-7398-nix-audit.sh during the audit command when the detected OS is NixOS.

#### Scenario: NixOS system detected
- **WHEN** audit command runs and OS is detected as NixOS
- **THEN** PKGS-7398-nix-audit.sh is executed and output saved to nix-supply-chain-audit.txt

#### Scenario: Non-NixOS system
- **WHEN** audit command runs and OS is not NixOS
- **THEN** NixOS supply chain audit is skipped

### Requirement: Parse audit script output
The system SHALL parse the PASS/FAIL result from nix-supply-chain-audit.txt to determine supply chain security status.

#### Scenario: Audit passes
- **WHEN** nix-supply-chain-audit.txt contains "Result: PASS"
- **THEN** supply chain status is "✅ Secure (signatures enforced)"

#### Scenario: Audit fails
- **WHEN** nix-supply-chain-audit.txt contains "Result: FAIL"
- **THEN** supply chain status is "❌ Insecure" and specific issues are extracted

#### Scenario: Audit file missing
- **WHEN** nix-supply-chain-audit.txt does not exist
- **THEN** supply chain status is "Unknown"

### Requirement: Extract failure reasons
The system SHALL extract specific failure reasons from the audit output when status is FAIL.

#### Scenario: Multiple issues
- **WHEN** audit fails with multiple issues listed under "Issues identified:"
- **THEN** all issue reasons are extracted (e.g., "Signature enforcement disabled", "No trusted public keys")

### Requirement: Check store integrity status
The system SHALL extract store integrity verification status from the audit output.

#### Scenario: Store verification passed
- **WHEN** audit output contains "Store integrity: OK"
- **THEN** store integrity status is "Verified"

#### Scenario: Store verification failed or skipped
- **WHEN** audit output contains "Store integrity: WARNING"
- **THEN** store integrity status is "Warning"

### Requirement: Save audit output to file
The system SHALL save the complete nix-audit.sh output to nix-supply-chain-audit.txt in the output directory.

#### Scenario: Audit execution
- **WHEN** PKGS-7398-nix-audit.sh executes successfully
- **THEN** complete output (including all sections) is written to output-{hostname}-{user}-{date}/nix-supply-chain-audit.txt

#### Scenario: Audit execution fails
- **WHEN** PKGS-7398-nix-audit.sh fails to execute (missing script, permission error)
- **THEN** error message is logged and audit continues without failing

### Requirement: Detect NixOS from system data
The system SHALL determine if OS is NixOS by checking lynis-report.json or neofetch.json.

#### Scenario: Detection from lynis-report.json
- **WHEN** lynis-report.json contains `"os_name": "NixOS"`
- **THEN** system is identified as NixOS

#### Scenario: Detection from neofetch.json
- **WHEN** neofetch.json contains OS field matching "NixOS"
- **THEN** system is identified as NixOS

#### Scenario: Non-NixOS system
- **WHEN** neither file contains "NixOS" in OS fields
- **THEN** system is not identified as NixOS

### Requirement: Execute audit as current user
The system SHALL execute PKGS-7398-nix-audit.sh as the actual user (not root) to get correct Nix configuration.

#### Scenario: Running with sudo
- **WHEN** audit command is run with sudo
- **THEN** nix-audit.sh is executed as SUDO_USER to read user's Nix configuration

#### Scenario: Running as regular user
- **WHEN** audit command is run without sudo
- **THEN** nix-audit.sh is executed as current user
