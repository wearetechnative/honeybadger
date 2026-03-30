## 1. Script Setup

- [x] 1.1 Create lib/generate-final-report.sh with proper shebang and executable permissions
- [x] 1.2 Implement command-line argument parsing for output directory path
- [x] 1.3 Add usage/help message display when arguments are missing or invalid
- [x] 1.4 Implement output directory validation (exists and contains required files)

## 2. Data Extraction Functions

- [x] 2.1 Create function to extract serial number from hardware-serial.txt
- [x] 2.2 Create function to extract hostname from lynis-report.json or system files
- [x] 2.3 Create function to extract hardware model from lynis-report.json
- [x] 2.4 Create function to detect current user (SUDO_USER env var or directory name parsing)
- [x] 2.5 Create function to extract NixOS metadata from nixos-system-info.txt (with graceful handling if missing)
- [x] 2.6 Create function to extract audit date from directory name or file timestamp

## 3. OS and Kernel Status Extraction

- [x] 3.1 Create function to extract OS type, version, and architecture from lynis-report.json
- [x] 3.2 Create function to extract kernel version from lynis-report.json
- [x] 3.3 Create function to parse os-kernel-status.txt for EOL status
- [x] 3.4 Create function to determine kernel support status (✅ Supported / ❌ EOL / ⚠️ Unknown)
- [x] 3.5 Create function to determine OS update stream status (✅ Active / ❌ Inactive / ⚠️ Extended Support)

## 4. Security Controls Extraction

- [x] 4.1 Create function to parse blockdevices.txt for disk encryption status (detect crypto_LUKS/dm-crypt)
- [x] 4.2 Create function to parse screenlock-info.txt for auto-lock configuration
- [x] 4.3 Create function to determine screen lock compliance (≤15 minutes = ✅, >15 = ⚠️, none = ❌)
- [x] 4.4 Create function to extract last update date from os-update-history.txt
- [x] 4.5 Create function to extract firewall status from lynis-report.json or asset-inventory.txt

## 5. Compliance Metrics Extraction

- [x] 5.1 Create function to extract Lynis hardening score from lynis-report.json (hardening_index field)
- [x] 5.2 Create function to determine score compliance status (≥65 = ✅, <65 = ❌)
- [x] 5.3 Create function to extract and count critical findings from lynis-report.json warnings array
- [x] 5.4 Create function to extract and count high severity findings from lynis-report.json warnings array
- [x] 5.5 Create function to format critical/high findings for display in report

## 6. Report Template and Generation

- [x] 6.1 Create embedded markdown template with sections: Asset Identification, Operating System, Security Controls, Compliance Metrics
- [x] 6.2 Implement function to populate Asset Identification table (serial, hostname, model, user, NixOS metadata)
- [x] 6.3 Implement function to populate Operating System table (OS type, version, kernel, architecture, support status, update stream)
- [x] 6.4 Implement function to populate Security Controls table (disk encryption, screen lock, OS updates, firewall)
- [x] 6.5 Implement function to populate Compliance Metrics section (Lynis score, critical/high findings)
- [x] 6.6 Implement function to add audit metadata header (date, timestamp)

## 7. Error Handling and Validation

- [x] 7.1 Add file existence checks for all input files with graceful degradation
- [x] 7.2 Implement "Not available" placeholder for missing data fields
- [x] 7.3 Add error handling for jq parsing failures
- [x] 7.4 Add error handling for malformed input files
- [x] 7.5 Ensure script exits with appropriate error codes on failures

## 8. Report Output

- [x] 8.1 Implement function to write final-report.md to output directory
- [x] 8.2 Add success message with path to generated report
- [x] 8.3 Set appropriate file permissions on generated report

## 9. RUNME.sh Integration

- [x] 9.1 Locate the audit function in RUNME.sh
- [x] 9.2 Add call to lib/generate-final-report.sh at the end of audit function (after all output files are generated)
- [x] 9.3 Pass output directory path as argument to generate-final-report.sh
- [x] 9.4 Add error handling for report generation failures (non-blocking - audit should still complete)
- [x] 9.5 Add status message indicating final report generation

## 10. Testing and Documentation

- [x] 10.1 Test full audit flow with automatic report generation (all files present)
- [x] 10.2 Test script with partial audit output (some files missing)
- [x] 10.3 Test script with NixOS audit output
- [x] 10.4 Test script with non-NixOS audit output
- [x] 10.5 Verify final-report.md is created in output directory after audit completes
- [x] 10.6 Add inline comments to document complex parsing logic
- [x] 10.7 Update README.md to mention final-report.md in output files section
