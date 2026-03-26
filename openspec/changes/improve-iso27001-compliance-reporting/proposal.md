## Why

The current Honeybadger audit has critical gaps in ISO27001 compliance reporting. Key requirements like device serial numbers, OS update history tracking, and Lynis hardening score validation are either missing or incomplete, preventing proper policy compliance verification and asset inventory management.

## What Changes

- Add device serial number collection using `dmidecode` to properly identify hardware assets
- Integrate existing `lib/check-os-updates.sh` script into audit workflow to track OS update history
- Display Lynis hardening score (0-100) in asset inventory reports
- Add validation that Lynis hardening score meets minimum threshold of ≥65
- Collect NixOS-specific metadata (nixpkgs commit hash, system generation, rebuild date)
- Implement severity-based categorization for Lynis findings (critical/high/medium/low)
- Review and decide on architectural approach for OS checking (keep separate or merge scripts)

## Capabilities

### New Capabilities
- `serial-number-collection`: Hardware serial number retrieval and reporting in asset inventory
- `update-history-tracking`: OS update history collection showing last update date and available updates
- `hardening-score-display`: Lynis hardening score visualization in compliance reports
- `hardening-score-validation`: Compliance threshold checking for Lynis scores (minimum ≥65)
- `nixos-metadata-collection`: NixOS-specific system information (commit hash, generation, rebuild date)
- `finding-severity-categorization`: Severity-based filtering and grouping of Lynis security findings

### Modified Capabilities
<!-- No existing capabilities are being modified - these are new additions -->

## Impact

**Code Changes:**
- `lib/_library`: Update `generate_asset_inventory()` function to collect and display serial number, hardening score, and NixOS metadata (~50 lines added)
- `RUNME.sh`: Add calls to `check-os-updates.sh`, `dmidecode`, and NixOS info commands in audit function (~30 lines added)
- `lib/_library`: Enhance `generate_warnings_report()` to filter findings by severity (~40 lines modified)

**Documentation Updates:**
- Update README.md with new compliance requirements and thresholds
- Add notes about dmidecode requirement (needs root/sudo)

**New Output Files:**
- `os-update-history.txt`: OS update status and last update date
- `nixos-system-info.txt`: NixOS commit hash and generation info (NixOS only)

**Affected Stakeholders:**
- Compliance auditors: Better visibility into policy compliance (serial numbers, update history, hardening scores)
- System administrators: Clear thresholds for pass/fail criteria (Lynis score ≥65)
- NixOS users: Reproducibility tracking via commit hashes and system generations
