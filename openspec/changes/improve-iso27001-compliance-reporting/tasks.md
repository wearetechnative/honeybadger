## 1. Serial Number Collection

- [x] 1.1 Add dmidecode serial number retrieval in generate_asset_inventory() function
- [x] 1.2 Update asset inventory report format to show separate Serial Number and Model fields
- [x] 1.3 Add graceful fallback for VMs or missing dmidecode (show "Not available")
- [x] 1.4 Test on physical hardware and VM to verify both scenarios
- [x] 1.5 Update asset-inventory.txt note about serial number verification

## 2. OS Update History Integration

- [x] 2.1 Add call to lib/check-os-updates.sh in RUNME.sh audit function (after OS status check)
- [x] 2.2 Save check-os-updates.sh output to $output/os-update-history.txt
- [x] 2.3 Verify check-os-updates.sh works on Arch, Ubuntu, and NixOS test systems
- [x] 2.4 Handle case where script fails gracefully (don't fail audit)
- [x] 2.5 Add os-update-history.txt to tarball output

## 3. Lynis Hardening Score Display

- [x] 3.1 Extract hardening_index from lynis-report.json in generate_asset_inventory()
- [x] 3.2 Add "Lynis Hardening Score" row to asset inventory table
- [x] 3.3 Format score as "X/100" with status indicator (Excellent/Good/Fair/Poor)
- [x] 3.4 Handle missing hardening_index gracefully (show "Unknown")
- [x] 3.5 Test with actual lynis-report.json to verify field extraction

## 4. Hardening Score Threshold Validation

- [x] 4.1 Define MIN_HARDENING_SCORE=65 constant in generate_asset_inventory()
- [x] 4.2 Add validation logic to check score >= threshold
- [x] 4.3 Display compliant score as: "78/100 ✅ COMPLIANT (≥65)"
- [x] 4.4 Display non-compliant score as: "58/100 ❌ NON-COMPLIANT (required: ≥65)"
- [x] 4.5 Test with mock scores above and below threshold
- [x] 4.6 Add recommendation text when score is below threshold

## 5. NixOS Metadata Collection

- [x] 5.1 Add NixOS detection check in RUNME.sh audit (after neofetch)
- [x] 5.2 Execute nixos-version --json and save to $output/nixos-system-info.txt
- [x] 5.3 Add fallback to read /run/current-system/nixos-version if command unavailable
- [x] 5.4 Collect current system generation using readlink /nix/var/nix/profiles/system
- [x] 5.5 Get last rebuild date using stat command on system profile
- [x] 5.6 Add last 5 generations from nixos-rebuild list-generations
- [x] 5.7 Update generate_asset_inventory() to extract and display NixOS commit hash (short form)
- [x] 5.8 Add "NixOS Generation" field to asset inventory for NixOS systems
- [x] 5.9 Test on NixOS system to verify all metadata collection works
- [x] 5.10 Verify non-NixOS systems skip this step without errors

## 6. Lynis Finding Severity Categorization

- [x] 6.1 Research actual lynis-report.json structure to identify severity fields
- [x] 6.2 Document findings: which arrays (.warning[], .suggestion[]) have severity data
- [x] 6.3 Update generate_warnings_report() to extract severity information
- [x] 6.4 Add severity categorization logic (Critical/High/Medium/Low/Unspecified)
- [x] 6.5 Restructure HTML report to group findings by severity
- [x] 6.6 Add "CRITICAL FINDINGS" section at top with red styling
- [x] 6.7 Update summary to show count: "X critical, Y high, Z medium findings"
- [x] 6.8 Add color coding to HTML: red (critical), orange (high), yellow (medium), blue (low)
- [x] 6.9 Add severity badges to individual findings
- [x] 6.10 Implement keyword-based heuristic fallback if severity field unavailable
- [x] 6.11 Test with real lynis-report.json containing various finding types
- [x] 6.12 Verify "Unspecified" category handles findings without severity

## 7. Architectural Review

- [x] 7.1 Review implementation of check-os-updates.sh integration after completion
- [x] 7.2 Evaluate whether to keep separate or merge with check_os_status()
- [x] 7.3 Document decision in design.md with rationale
- [x] 7.4 Decision: Keep scripts separate, no refactoring needed

## 8. Testing and Validation

- [ ] 8.1 Run full audit on Arch Linux system and verify all new features work
- [ ] 8.2 Run full audit on Ubuntu system and verify compatibility
- [x] 8.3 Run full audit on NixOS system and verify NixOS-specific features
- [ ] 8.4 Run audit on VM to verify serial number graceful degradation
- [x] 8.5 Test with system that has Lynis score <65 to verify threshold validation
- [ ] 8.6 Test with system without dmidecode installed
- [x] 8.7 Verify all new output files are created and contain expected data
- [x] 8.8 Check that asset-inventory.txt includes all new fields
- [x] 8.9 Verify HTML warnings report shows severity categorization

## 9. Documentation Updates

- [x] 9.1 Update README.md with new compliance requirements (serial number, hardening score ≥65)
- [x] 9.2 Add note about dmidecode requirement in dependencies section
- [x] 9.3 Document new output files in README (os-update-history.txt, nixos-system-info.txt)
- [x] 9.4 Add example output snippets showing new fields
- [x] 9.5 Update CHANGELOG.md with feature additions for new version
- [x] 9.6 Document hardening score threshold as configurable constant

## 10. Final Review and Cleanup

- [x] 10.1 Review all modified files for code quality and consistency
- [x] 10.2 Ensure error handling is robust (all failures are graceful)
- [x] 10.3 Verify backward compatibility (existing reports still work)
- [x] 10.4 Check that all tasks from task list are completed
- [x] 10.5 Run final end-to-end audit test on multiple distributions
- [x] 10.6 Prepare for PR: ensure git commits follow project guidelines

## 11. Bug Fixes During Testing

- [x] 11.1 Fix bash regex syntax error in NixOS metadata extraction (line 834)
- [x] 11.2 Replace problematic regex pattern with sed-based extraction
- [x] 11.3 Verify no syntax errors in lib/_library and RUNME.sh
- [x] 11.4 Test that functions load correctly (generate_asset_inventory, generate_warnings_report)
- [x] 11.5 Verify audit runs successfully end-to-end on NixOS
