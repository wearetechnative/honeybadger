## Why

The current Honeybadger tool only supports ISO27001 compliance reporting for Linux and macOS systems. Windows systems need equivalent compliance reporting to audit disk encryption (BitLocker), screen lock configuration, firewall status, OS update status, and system hardening (via HardeningKitty) against the same ISO27001 requirements.

## What Changes

- Enhance `RUNME.ps1` to collect all required Windows security data (BitLocker, screen lock settings, firewall, Windows Update, Windows Defender, hardware serial number, system info)
- Generate ISO27001 compliance reports in markdown format matching the Linux/macOS report structure
- Integrate HardeningKitty security audit results into compliance reporting
- Create `honeybadger-{user}-{date}-compliance.md` with pass/fail compliance checklist
- Create `honeybadger-{user}-{date}-actions.md` with prioritized remediation items from HardeningKitty findings
- Collect comprehensive screen lock data (screensaver timeout, power management, lock policies, inactivity timeouts)
- **Clean up HardeningKitty baseline lists**: Remove Windows 10, Server, Edge, Office lists (113 → 15 lists, 4.9MB → 856KB) - keep only Windows 11 and default lists
- **Add ZIP archive generation**: Automatically create `honeybadger-{hostname}-{user}-{date}.zip` containing all reports and data
- **Add report submission functionality**: New `submit-report.ps1` script to upload ZIP archives to server using PowerShell Invoke-WebRequest (compatible with existing .honeybadger.conf configuration)
- **Improve Windows user experience**: Rename `RUNME.ps1` → `AUDIT.ps1` and add `RUNME.cmd` launcher that handles ExecutionPolicy and Administrator check automatically (users can now double-click to run)
- **Fix BitLocker compliance check**: Verify both VolumeStatus (encrypted) AND ProtectionStatus (not suspended) for accurate compliance detection

## Capabilities

### New Capabilities
- `windows-compliance-reporting`: Generate ISO27001 compliance reports for Windows systems with pass/fail status for disk encryption, screen lock, firewall, OS updates, and antivirus
- `windows-security-data-collection`: Collect Windows-specific security data including BitLocker status, screen lock configuration, firewall profiles, Windows Update history, Windows Defender status, and hardware serial numbers
- `hardeningkitty-integration`: Parse and integrate HardeningKitty CSV audit results into compliance reports and action lists

### Modified Capabilities
<!-- No existing capabilities are being modified - this is net new Windows support -->

## Impact

**Modified Files:**
- `RUNME.ps1` → `AUDIT.ps1`: Enhanced from minimal 16-line script to full ISO27001 audit and reporting tool (700+ lines), renamed for clarity
- `HardeningKitty/lists/`: Cleaned up from 113 baseline lists (4.9MB) to 15 Windows 11-specific lists (856KB) - 82.5% reduction

**Removed Files:**
- 98 HardeningKitty baseline lists for Windows 10, Server, Edge, Office, DoD STIG, BSI SiSyPHuS (only Windows 11 + default lists retained)

**New Files:**
- `RUNME.cmd`: Windows batch launcher that handles ExecutionPolicy and Administrator privileges automatically (double-click to run)
- `AUDIT.ps1`: Main audit script (renamed from RUNME.ps1 for clarity)
- `submit-report.ps1`: Standalone script to upload ZIP archives to configured server (uses Invoke-WebRequest, compatible with .honeybadger.conf)
- Generated reports: `honeybadger-{user}-{date}-compliance.md` and `honeybadger-{user}-{date}-actions.md`
- ZIP archive: `honeybadger-{hostname}-{user}-{date}.zip` (automatically created, contains all reports)
- Intermediate data files in `report-{date}/` directory (bitlocker_result.txt, hardeningkitty.csv, neofetch.txt)

**Dependencies:**
- Existing: HardeningKitty PowerShell module (already included in repo, now with only Windows 11 baselines)
- New: neofetch (installable via `winget install neofetch` if missing)
- Windows built-ins: Get-BitLockerVolume, Get-NetFirewallProfile, Get-MpComputerStatus, Get-HotFix, Get-CimInstance, Compress-Archive

**User Impact:**
- Windows users can now run `.\RUNME.ps1` to generate ISO27001 compliance reports equivalent to Linux/macOS systems
- Reports follow same structure and compliance thresholds as Linux version for consistency
- BitLocker compliance check now correctly detects suspended protection (critical security fix)
- Automatic ZIP archive creation for easy report sharing
- Optional report submission to server via `.\submit-report.ps1` (uses same .honeybadger.conf as Linux version)
- Smaller repo size due to HardeningKitty list cleanup (4.9MB → 856KB)
- No changes to Linux/macOS functionality

**Workflow:**
1. Run audit: Right-click `RUNME.cmd` → "Run as administrator" (or run `.\AUDIT.ps1` from PowerShell)
2. Optional: Submit to server: `.\submit-report.ps1` (uploads ZIP with token authentication)

**Improved User Experience:**
- Double-click `RUNME.cmd` to start (automatically handles ExecutionPolicy and checks Administrator privileges)
- Clear warnings if not running as Administrator with explanation of affected checks
- Automatic pause at end so users can read results before window closes
