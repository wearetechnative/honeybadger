## 1. Script Structure Setup

- [x] 1.1 Back up current RUNME.ps1 (save as RUNME.ps1.old)
- [x] 1.2 Create script header with error handling ($ErrorActionPreference, Administrator check)
- [x] 1.3 Define report directory creation logic (report-{date}/ with timestamp)
- [x] 1.4 Define global variables for collected data (system info, compliance status, findings)

## 2. System Information Collection

- [x] 2.1 Implement neofetch check and installation (try winget, fall back to WMI if fails)
- [x] 2.2 Collect hostname and username using $env:COMPUTERNAME and $env:USERNAME
- [x] 2.3 Collect hardware serial number from Get-CimInstance Win32_BIOS with VM detection
- [x] 2.4 Collect OS version information from neofetch or Win32_OperatingSystem
- [x] 2.5 Store system info in PowerShell variables for report generation

## 3. BitLocker Encryption Collection

- [x] 3.1 Check if running with Administrator privileges (required for Get-BitLockerVolume)
- [x] 3.2 Run Get-BitLockerVolume and capture output to variable with error handling
- [x] 3.3 Parse VolumeStatus, EncryptionPercentage, and KeyProtector for C: drive
- [x] 3.4 Determine compliance status (✅ if FullyEncrypted with 100%, ❌ otherwise)
- [x] 3.5 Save BitLocker output to report/bitlocker_result.txt for reference

## 4. Screen Lock Settings Collection

- [x] 4.1 Read screensaver settings from HKCU:\Control Panel\Desktop (ScreenSaveTimeOut, ScreenSaveActive, ScreenSaverIsSecure)
- [x] 4.2 Query power settings using powercfg (monitor timeout SUB_VIDEO VIDEOIDLE, system sleep SUB_SLEEP STANDBYIDLE)
- [x] 4.3 Read lock policy settings from HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization (NoLockScreen)
- [x] 4.4 Read require password on wake from HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings (ACSettingIndex)
- [x] 4.5 Read inactivity timeout from HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System (InactivityTimeoutSecs)
- [x] 4.6 Evaluate compliance (✅ if screensaver ≤900s AND active AND secure, ❌ otherwise)
- [x] 4.7 Store all screen lock data in variables for report section

## 5. Windows Firewall Collection

- [x] 5.1 Run Get-NetFirewallProfile with error handling (fall back to registry if cmdlet unavailable)
- [x] 5.2 Capture Enabled status for Domain, Private, and Public profiles
- [x] 5.3 Determine compliance status (✅ if all three profiles enabled, ❌ with list of disabled profiles)
- [x] 5.4 Store firewall status in variables

## 6. Windows Update Collection

- [x] 6.1 Run Get-HotFix and sort by InstalledOn descending to find most recent update
- [x] 6.2 Extract KB number, description, and installation date from most recent hotfix
- [x] 6.3 Calculate days since last update using (Get-Date) - InstalledOn
- [x] 6.4 Determine compliance status (✅ if <14 days, ⚠️ if 14-30 days, ❌ if >30 days)
- [x] 6.5 Handle case where Get-HotFix returns no results (report "Unable to determine")

## 7. Windows Defender Collection

- [x] 7.1 Run Get-MpComputerStatus with error handling (handle third-party antivirus case)
- [x] 7.2 Capture RealTimeProtectionEnabled, AntivirusSignatureVersion, AntivirusSignatureLastUpdated
- [x] 7.3 Calculate days since last definition update
- [x] 7.4 Determine compliance status (✅ if enabled AND definitions <7 days, ❌ otherwise)
- [x] 7.5 Store Defender status in variables

## 8. HardeningKitty Audit Execution

- [x] 8.1 Import HardeningKitty module from .\HardeningKitty\HardeningKitty.psm1 with error handling
- [x] 8.2 Run Invoke-HardeningKitty -Mode Config -Report -ReportFile report\hardeningkitty.csv
- [x] 8.3 Verify hardeningkitty.csv was created successfully (check file exists and not empty)

## 9. HardeningKitty Results Parsing

- [x] 9.1 Import hardeningkitty.csv using Import-Csv cmdlet
- [x] 9.2 Calculate total checks count (total CSV rows)
- [x] 9.3 Filter failed checks where Result -ne Recommended
- [x] 9.4 Group failed checks by Severity (High, Medium, Low) with default to Low if empty
- [x] 9.5 Count passed checks (Result -eq Recommended)
- [x] 9.6 Get unique Category values for statistics
- [x] 9.7 Store parsed findings in variables for report generation

## 10. Compliance Report Generation

- [x] 10.1 Create PowerShell here-string template for compliance.md structure
- [x] 10.2 Populate system information section (hostname, user, date, serial number, OS version)
- [x] 10.3 Generate compliance checklist table with all controls and status (✅/⚠️/❌)
- [x] 10.4 Add detailed screen lock configuration section with all collected settings
- [x] 10.5 Add BitLocker section with volume details and encryption status
- [x] 10.6 Add firewall section with profile status (Domain/Private/Public)
- [x] 10.7 Add Windows Update section with last update date and days ago
- [x] 10.8 Add Windows Defender section with real-time protection and definition status
- [x] 10.9 Add HardeningKitty summary section (total checks, passed/failed, categories)
- [x] 10.10 Write compliance report to report-{date}/honeybadger-{user}-{date}-compliance.md

## 11. Actions Report Generation

- [x] 11.1 Create PowerShell here-string template for actions.md structure
- [x] 11.2 Add report header with system info and date
- [x] 11.3 Generate High Severity section with failed findings (ID, Category, Name, Result vs Recommended)
- [x] 11.4 Generate Medium Severity section with failed findings
- [x] 11.5 Generate Low Severity section with failed findings
- [x] 11.6 Handle case where no findings exist (all checks passed message)
- [x] 11.7 Write actions report to report-{date}/honeybadger-{user}-{date}-actions.md

## 12. Error Handling and Validation

- [x] 12.1 Add try-catch blocks around all Get-* cmdlets with meaningful error messages
- [x] 12.2 Add privilege check at script start (warn if not Administrator, list affected checks)
- [x] 12.3 Validate report directory was created successfully
- [x] 12.4 Verify both compliance.md and actions.md were written successfully
- [x] 12.5 Add final success message with paths to generated reports
- [x] 12.6 Create ZIP archive of report directory (honeybadger-{hostname}-{user}-{date}.zip)

## 13. Testing and Documentation

- [ ] 13.1 Test script on Windows 11 with BitLocker enabled
- [ ] 13.2 Test script on Windows 10 with BitLocker disabled
- [ ] 13.3 Test script without Administrator privileges (verify graceful degradation)
- [ ] 13.4 Test neofetch installation fallback (remove neofetch first)
- [ ] 13.5 Test with sample HardeningKitty CSV containing failed checks across all severities
- [ ] 13.6 Verify compliance report shows all required sections
- [ ] 13.7 Verify actions report groups findings by severity correctly
- [ ] 13.8 Update README.md with Windows usage instructions (Administrator requirement, execution command)
- [ ] 13.9 Add sample output screenshots to documentation (compliance.md and actions.md examples)
- [ ] 13.10 Test execution command: powershell -ExecutionPolicy Bypass -File .\RUNME.ps1
