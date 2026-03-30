## Context

The Honeybadger tool currently supports ISO27001 compliance reporting only for Linux/macOS via `RUNME.sh` using Lynis for security auditing. Windows systems use a minimal `RUNME.ps1` (16 lines) that only collects BitLocker and HardeningKitty data without any compliance reporting.

The existing Windows script structure:
- Runs Get-BitLockerVolume → `report/bitlocker_result.txt`
- Imports HardeningKitty → runs Config mode → `report/hardeningkitty.csv`
- No neofetch, no other security checks, no report generation

The Linux/macOS ISO27001 reporting (from `iso27001-compliance-reporting-overhaul` change) generates:
- `honeybadger-{user}-{date}-compliance.md`: Executive compliance checklist
- `honeybadger-{user}-{date}-actions.md`: Prioritized remediation items

**Constraints:**
- Must maintain PowerShell-only implementation (no WSL/Bash dependencies)
- Must work with existing HardeningKitty module already in repo
- Should align with Linux/macOS report structure for consistency
- Must handle cases where tools (neofetch, specific cmdlets) are missing
- Administrator/elevated privileges required for BitLocker, firewall, and Defender checks

**Stakeholders:**
- Windows users requiring ISO27001 laptop compliance audits
- IT administrators managing Windows device security
- Compliance auditors reviewing security posture

## Goals / Non-Goals

**Goals:**
- Enable Windows systems to generate ISO27001 compliance reports matching Linux/macOS format
- Collect all required security data: BitLocker, screen lock, firewall, Windows Update, Defender, serial number, system info
- Parse HardeningKitty CSV and integrate findings into compliance/action reports
- Provide clear pass/fail compliance status for each ISO27001 control
- Handle missing tools gracefully (install neofetch via winget if missing, fall back when cmdlets unavailable)
- Keep all logic in single RUNME.ps1 file (no separate helper scripts)

**Non-Goals:**
- Calculating HardeningKitty score (no score needed, just pass/fail on findings)
- Creating multiple intermediate files like Linux version does (keep it simple)
- Supporting non-Windows platforms in this change
- Automated remediation of security findings
- Real-time monitoring or scheduled audits
- Web-based or GUI reporting

## Decisions

### Decision 1: Single-phase execution instead of audit + check-output commands

**Chosen:** Run all data collection and report generation in one RUNME.ps1 execution

**Rationale:**
- Simpler user experience: just run `.\RUNME.ps1` once
- No need for tarball packaging like Linux version (Windows users typically work directly on target system)
- Reduces complexity: no need to manage intermediate state between phases
- All collected data stays in memory or temp variables, only final reports written to disk

**Alternatives considered:**
- Separate audit and check-output commands like Linux: Over-engineering for Windows use case where users audit their own machine
- Write intermediate JSON/XML: Unnecessary I/O when all processing happens in single script run

### Decision 2: Comprehensive screen lock data collection instead of single timeout value

**Chosen:** Collect all screen lock related settings (screensaver, power management, lock policies, inactivity timeout)

**Rationale:**
- Windows has multiple overlapping mechanisms for screen lock (screensaver, display sleep, system lock policy)
- No single "screen lock timeout" value exists
- Compliance auditors need full picture: screensaver config, power timeouts, policy enforcement
- Present all data in report, let auditor evaluate (vs trying to synthesize single value)

**Implementation approach:**
```powershell
# Registry keys for screensaver
HKCU:\Control Panel\Desktop\ScreenSaveTimeOut
HKCU:\Control Panel\Desktop\ScreenSaveActive
HKCU:\Control Panel\Desktop\ScreenSaverIsSecure

# Power settings via powercfg
powercfg /q SCHEME_CURRENT SUB_VIDEO VIDEOIDLE    # Monitor timeout
powercfg /q SCHEME_CURRENT SUB_SLEEP STANDBYIDLE  # System sleep

# Policy settings
HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization\NoLockScreen
HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\ACSettingIndex
HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\InactivityTimeoutSecs
```

**Alternatives considered:**
- Only check screensaver timeout: Incomplete, misses modern power management settings
- Calculate single "effective timeout": Complex logic, error-prone with overlapping settings

### Decision 3: In-memory data processing with minimal intermediate files

**Chosen:** Store collected data in PowerShell variables, generate reports directly without writing intermediate files (except HardeningKitty CSV which is needed for reference)

**Rationale:**
- Report generation happens immediately after data collection (single script execution)
- No need for intermediate txt files like Linux version uses
- Cleaner output directory: only compliance.md, actions.md, and hardeningkitty.csv
- Reduces disk I/O and file management complexity

**Alternatives considered:**
- Match Linux approach with many intermediate files: Creates clutter, unnecessary for single-phase execution
- Write everything to JSON intermediate: Adds serialization complexity without benefit

### Decision 4: Use Import-Csv for HardeningKitty parsing instead of custom CSV parser

**Chosen:** Leverage PowerShell's built-in Import-Csv cmdlet to parse hardeningkitty.csv into objects

**Rationale:**
- Native PowerShell cmdlet handles CSV parsing correctly (quotes, escaping, headers)
- Returns objects with properties matching CSV columns (ID, Category, Name, Severity, Result, Recommended)
- Simple filtering: `$findings | Where-Object { $_.Result -ne $_.Recommended }`
- No external dependencies or custom parsing logic needed

**Alternatives considered:**
- Manual CSV parsing with Get-Content: Error-prone, reinventing the wheel
- ConvertFrom-Csv with custom logic: Import-Csv is more appropriate for file input

### Decision 5: Graceful degradation for missing tools and insufficient permissions

**Chosen:** Attempt to install missing tools (neofetch via winget), fall back to alternative data sources, report "unavailable" instead of failing

**Rationale:**
- Users may run script without checking prerequisites
- Some systems have restricted winget access or network limitations
- Script should provide partial results rather than complete failure
- Clear messaging about what couldn't be collected helps troubleshooting

**Implementation approach:**
```powershell
# Try neofetch, fall back to WMI
if (Get-Command neofetch -ErrorAction SilentlyContinue) {
    neofetch | Out-File report\neofetch.txt
} else {
    # Try winget install
    winget install neofetch 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        neofetch | Out-File report\neofetch.txt
    } else {
        # Fall back to WMI
        $os = Get-CimInstance Win32_OperatingSystem
        # Format manually...
    }
}

# Handle missing cmdlets
try {
    $bitlocker = Get-BitLockerVolume -ErrorAction Stop
} catch {
    $bitlockerStatus = "Unable to check BitLocker - Administrator privileges required"
}
```

**Alternatives considered:**
- Strict prerequisites check at start: Annoying, prevents partial results
- Fail loudly on missing tools: Provides no value to user

### Decision 6: Align compliance thresholds with Linux version where applicable

**Chosen:** Use same or equivalent thresholds for common controls (OS updates <30 days critical, <14 days compliant)

**Rationale:**
- Consistency across platforms for compliance auditing
- ISO27001 requirements don't differ by OS
- Screen lock thresholds align: ≤15 minutes (900 seconds)
- Allows apples-to-apples comparison of Windows vs Linux systems

**Thresholds:**
- Disk encryption: BitLocker enabled and fully encrypted (100%)
- Screen lock: Screensaver timeout ≤900s AND active AND secure
- Firewall: All profiles (Domain, Private, Public) enabled
- OS updates: <14 days ✅, 14-30 days ⚠️, >30 days ❌
- Antivirus: Real-time protection enabled AND definitions <7 days old

**Alternatives considered:**
- Windows-specific thresholds: Creates inconsistency, confuses auditors
- Stricter thresholds: Would fail more systems unnecessarily

### Decision 7: PowerShell here-strings for markdown template generation

**Chosen:** Use PowerShell here-strings (@" "@) to define markdown report templates with variable interpolation

**Rationale:**
- Readable multi-line strings without escape characters
- Native variable substitution: `$hostname`, `$complianceStatus`
- Easier to maintain report format
- Natural fit for generating markdown documents

**Example:**
```powershell
$complianceReport = @"
# ISO27001 Compliance Report - Windows

**System**: $hostname
**User**: $username
**Date**: $reportDate
**Serial Number**: $serialNumber

## Compliance Checklist

| Control | Status | Details |
|---------|--------|---------|
| Disk Encryption | $diskEncryptionStatus | $diskEncryptionDetails |
"@
```

**Alternatives considered:**
- String concatenation: Messy, hard to read, error-prone
- Separate template file: Over-engineering, adds file dependency

### Decision 8: Report directory structure matches output-{hostname}-{user}-{date} pattern

**Chosen:** Create `report-{date}/` directory for all collected data, write final reports as `report-{date}/honeybadger-{user}-{date}-compliance.md` and `actions.md`

**Rationale:**
- Keeps collected data (hardeningkitty.csv, bitlocker_result.txt) and generated reports in one place
- Timestamp in directory name allows multiple audit runs without overwriting
- Matches user's current usage pattern (Linda's report: report-20260330/)
- Simpler than Linux's separate output directory structure

**Alternatives considered:**
- Separate directories for data vs reports: Unnecessary complexity
- Flat file structure without directory: Creates clutter in script root

## Risks / Trade-offs

**Risk:** Screen lock compliance evaluation is ambiguous with multiple overlapping settings
→ **Mitigation:** Present all collected screen lock data in report, document all values, let auditor make final determination; provide guidance on what constitutes compliance

**Risk:** HardeningKitty CSV may have 1000+ findings, creating very large actions.md files
→ **Mitigation:** Group findings by severity, optionally filter to show only High/Medium severity in actions report (configurable threshold)

**Risk:** Users may run script without Administrator privileges, causing some checks to fail
→ **Mitigation:** Detect elevation status at start, warn user, gracefully handle cmdlet failures, report "requires Administrator" for unavailable data

**Risk:** Neofetch installation via winget may fail on restricted systems
→ **Mitigation:** Fall back to WMI-based system info collection (Get-CimInstance Win32_OperatingSystem, Win32_ComputerSystem), provide equivalent data

**Risk:** PowerShell execution policy may block script execution
→ **Mitigation:** Document execution command: `powershell -ExecutionPolicy Bypass -File .\RUNME.ps1`, check execution policy at runtime and provide clear error message with fix

**Trade-off:** Single-phase execution means no ability to review collected data before generating reports
→ **Justification:** Windows users typically audit their own machine immediately; separation of concerns (audit vs report) less valuable than simplicity; hardeningkitty.csv remains available for manual review

**Trade-off:** No HardeningKitty score calculation means less comparable to Lynis hardening index
→ **Justification:** User explicitly requested no score; focus on pass/fail findings; HardeningKitty scoring formula may differ from Lynis anyway; compliance is about specific controls, not aggregate score

**Risk:** Windows Update history via Get-HotFix may not reflect all update types (driver updates, Microsoft Store app updates)
→ **Mitigation:** Document that "last update" refers to Windows hotfixes/security updates; adequate for ISO27001 patch management verification

## Migration Plan

**Deployment Steps:**
1. Replace current RUNME.ps1 (16 lines) with enhanced version
2. Test on Windows 10/11 systems with varying configurations
3. Verify Administrator privilege detection works correctly
4. Test neofetch installation fallback scenario
5. Validate report generation with sample HardeningKitty CSV data
6. Update README.md with Windows-specific usage instructions

**Testing Checklist:**
- [ ] Script runs on Windows 10 21H2+
- [ ] Script runs on Windows 11 22H2+
- [ ] BitLocker enabled system: reports compliant
- [ ] BitLocker disabled system: reports non-compliant
- [ ] All three firewall profiles checked correctly
- [ ] Windows Update date calculation correct (<14 days, 14-30 days, >30 days)
- [ ] Screen lock settings all collected and displayed
- [ ] HardeningKitty CSV parsed correctly
- [ ] Actions report generated with findings grouped by severity
- [ ] Compliance report includes all required sections
- [ ] Neofetch fallback to WMI works when neofetch unavailable
- [ ] Graceful handling of insufficient permissions (non-Admin user)

**Rollback Strategy:**
- Git revert to previous RUNME.ps1 version
- No data loss risk (input: system state; output: report files)
- No dependencies to roll back (HardeningKitty already in repo)

**User Communication:**
- Update README.md "Usage on Windows" section
- Document required privileges (Administrator)
- Document execution command with `-ExecutionPolicy Bypass`
- Provide sample output screenshots

## Open Questions

None - design is ready for implementation.
