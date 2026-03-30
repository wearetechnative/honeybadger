## 1. Library Functions - NixOS Detection and Parsing

- [x] 1.1 Add `is_nixos()` helper function to detect NixOS from lynis-report.json or neofetch.json
- [x] 1.2 Add `check_nixos_supply_chain()` function to parse nix-supply-chain-audit.txt
- [x] 1.3 Implement PASS/FAIL result parsing from audit output
- [x] 1.4 Implement failure reason extraction from "Issues identified:" section
- [x] 1.5 Implement store integrity status extraction
- [x] 1.6 Return "Unknown" status when audit file is missing

## 2. RUNME.sh Audit Integration

- [x] 2.1 Add NixOS detection check in audit() function after neofetch collection
- [x] 2.2 Execute PKGS-7398-nix-audit.sh as SUDO_USER when NixOS detected
- [x] 2.3 Save nix-audit output to $output/nix-supply-chain-audit.txt
- [x] 2.4 Add error handling - continue audit if nix-audit fails
- [x] 2.5 Add console message when nix-audit is executed
- [x] 2.6 Verify script is not executed on non-NixOS systems

## 3. Compliance Report Integration

- [x] 3.1 Update generate_compliance_report() to call check_nixos_supply_chain()
- [x] 3.2 Add NixOS supply chain row to compliance checklist table (conditional on is_nixos)
- [x] 3.3 Add supply chain failure to critical_issues array when status is FAIL
- [x] 3.4 Calculate correct status icon for supply chain row (✅ for PASS, ❌ for FAIL)
- [x] 3.5 Add NixOS Supply Chain Audit subsection to system information when audit file exists
- [x] 3.6 Include complete audit output in system information section

## 4. Asset Inventory Integration

- [x] 4.1 Update generate_asset_inventory() to call check_nixos_supply_chain()
- [x] 4.2 Add "NixOS Supply Chain" field to asset inventory table for NixOS systems
- [x] 4.3 Display status as "Secure (sigs enforced)" for PASS or "Insecure" for FAIL
- [x] 4.4 Omit field from table for non-NixOS systems

## 5. Testing and Validation

- [x] 5.1 Test audit on NixOS system with passing supply chain (require-sigs=true)
- [x] 5.2 Test audit on NixOS system with failing supply chain (temporarily disable require-sigs)
- [x] 5.3 Test audit on non-NixOS system (should skip nix-audit gracefully)
- [x] 5.4 Test check-output with NixOS audit results (verify compliance report shows supply chain)
- [x] 5.5 Test check-output with old audit tarball missing nix-supply-chain-audit.txt
- [x] 5.6 Test with missing PKGS-7398-nix-audit.sh file (should log error and continue)
- [x] 5.7 Verify compliance report marks supply chain FAIL as CRITICAL issue
- [x] 5.8 Verify asset inventory includes NixOS supply chain field
- [x] 5.9 Verify system information section includes audit output

## 6. Documentation

- [x] 6.1 Add code comments documenting NixOS supply chain check logic
- [x] 6.2 Update ISO27001-LAPTOP-COMPLIANCE.md to mention NixOS supply chain check
- [x] 6.3 Document nix-supply-chain-audit.txt output file format
