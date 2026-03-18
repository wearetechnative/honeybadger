## Why

Vulnix and Trivy CVE scanning functionality has been determined to be obsolete and should be removed from Honeybadger. These tools were added as mandatory dependencies in v0.4.0 for ISO27001 Policy 8.1 compliance, but are no longer needed for the project's objectives.

## What Changes

- Remove all CVE vulnerability scanning code from the codebase
- Remove vulnix and trivy as required dependencies
- Remove CVE scanning from the audit workflow
- Remove CVE report generation and submission logic
- Update documentation to reflect removal of CVE scanning capabilities
- **BREAKING**: Audit command will no longer require vulnix/trivy to be installed
- **BREAKING**: CVE scanning results (vulnix.json, trivy.json, cve-summary.txt) will no longer be generated
- **BREAKING**: Server submission will no longer include CVE scan reports

## Capabilities

### New Capabilities
<!-- No new capabilities are being introduced -->

### Modified Capabilities
<!-- No existing capabilities are having their requirements modified - this is a pure removal -->

## Impact

**Code Changes:**
- `lib/_library`: Remove ~150 lines of CVE scanning functions (scan_cve_vulnerabilities, scan_vulnix, scan_trivy, generate_cve_summary, generate_vulnix_summary, generate_trivy_summary)
- `RUNME.sh`: Remove dependency checks and CVE function calls (~15 lines)

**Documentation Updates:**
- `README.md`: Remove CVE scanner installation instructions and dependency requirements
- `CHANGELOG.md`: Document removal as breaking change in new version entry
- `openspec/project.md`: Update feature list and external dependencies

**OpenSpec Changes:**
- Archive or remove CVE-related change directories (add-cve-vulnerability-scanning, make-cve-scanners-required, add-cve-scanner-dependency-checks)

**Functionality Impact:**
- Users will no longer receive CVE vulnerability reports during audits
- ISO27001 Policy 8.1 patch management compliance gap (if still required, alternative solution needed)
- Report submission workflow no longer includes CVE scan files
- Output directories will not contain vulnix.json, trivy.json, or cve-summary.txt files
