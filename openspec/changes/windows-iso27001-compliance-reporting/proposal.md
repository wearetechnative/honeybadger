## Why

The current Honeybadger tool only supports ISO27001 compliance reporting for Linux and macOS systems. Windows systems need equivalent compliance reporting to audit disk encryption (BitLocker), screen lock configuration, firewall status, OS update status, and system hardening (via HardeningKitty) against the same ISO27001 requirements.

## What Changes

- Enhance `RUNME.ps1` to collect all required Windows security data (BitLocker, screen lock settings, firewall, Windows Update, Windows Defender, hardware serial number, system info)
- Generate ISO27001 compliance reports in markdown format matching the Linux/macOS report structure
- Integrate HardeningKitty security audit results into compliance reporting
- Create `honeybadger-{user}-{date}-compliance.md` with pass/fail compliance checklist
- Create `honeybadger-{user}-{date}-actions.md` with prioritized remediation items from HardeningKitty findings
- Collect comprehensive screen lock data (screensaver timeout, power management, lock policies, inactivity timeouts)

## Capabilities

### New Capabilities
- `windows-compliance-reporting`: Generate ISO27001 compliance reports for Windows systems with pass/fail status for disk encryption, screen lock, firewall, OS updates, and antivirus
- `windows-security-data-collection`: Collect Windows-specific security data including BitLocker status, screen lock configuration, firewall profiles, Windows Update history, Windows Defender status, and hardware serial numbers
- `hardeningkitty-integration`: Parse and integrate HardeningKitty CSV audit results into compliance reports and action lists

### Modified Capabilities
<!-- No existing capabilities are being modified - this is net new Windows support -->

## Impact

**Modified Files:**
- `RUNME.ps1`: Enhanced from minimal 16-line script to full ISO27001 audit and reporting tool

**New Files:**
- Generated reports: `honeybadger-{user}-{date}-compliance.md` and `honeybadger-{user}-{date}-actions.md`
- Intermediate data files in `report/` directory (bitlocker_result.txt, hardeningkitty.csv, etc.)

**Dependencies:**
- Existing: HardeningKitty PowerShell module (already included in repo)
- New: neofetch (installable via `winget install neofetch` if missing)
- Windows built-ins: Get-BitLockerVolume, Get-NetFirewallProfile, Get-MpComputerStatus, Get-HotFix, Get-CimInstance

**User Impact:**
- Windows users can now run `.\RUNME.ps1` to generate ISO27001 compliance reports equivalent to Linux/macOS systems
- Reports follow same structure and compliance thresholds as Linux version for consistency
- No changes to Linux/macOS functionality
