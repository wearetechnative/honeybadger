#Requires -Version 5.1
<#
.SYNOPSIS
    Honeybadger - Windows ISO27001 Compliance Audit Tool
.DESCRIPTION
    Collects Windows security configuration data and generates ISO27001 compliance reports
.NOTES
    Requires Administrator privileges for full functionality
    Run with: powershell -ExecutionPolicy Bypass -File .\RUNME.ps1
#>

# Task 1.2: Script header with error handling
$ErrorActionPreference = "Continue"  # Continue on errors to collect as much data as possible
$WarningPreference = "SilentlyContinue"

# Task 1.3: Report directory creation logic
$timestamp = Get-Date -Format "yyyyMMdd"
$reportDir = "report-$timestamp"

# Task 1.4: Global variables for collected data
$script:isAdmin = $false
$script:hostname = ""
$script:username = ""
$script:serialNumber = ""
$script:osVersion = ""
$script:reportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# BitLocker variables
$script:bitlockerStatus = ""
$script:bitlockerDetails = ""
$script:bitlockerCompliant = $false

# Screen lock variables
$script:screenSaveTimeOut = $null
$script:screenSaveActive = $null
$script:screenSaverSecure = $null
$script:monitorTimeout = $null
$script:systemSleep = $null
$script:lockOnSleep = $null
$script:requirePasswordOnWake = $null
$script:inactivityTimeout = $null
$script:screenLockCompliant = $false
$script:screenLockDetails = ""

# Firewall variables
$script:firewallDomain = $false
$script:firewallPrivate = $false
$script:firewallPublic = $false
$script:firewallCompliant = $false
$script:firewallDetails = ""

# Windows Update variables
$script:lastUpdateDate = $null
$script:lastUpdateKB = ""
$script:lastUpdateDaysAgo = 0
$script:updateCompliant = ""  # ✅, ⚠️, or ❌
$script:updateDetails = ""

# Windows Defender variables
$script:defenderEnabled = $false
$script:defenderSignatureDate = $null
$script:defenderSignatureVersion = ""
$script:defenderDaysOld = 0
$script:defenderCompliant = $false
$script:defenderDetails = ""

# HardeningKitty variables
$script:hkTotalChecks = 0
$script:hkPassedChecks = 0
$script:hkFailedChecks = 0
$script:hkHighSeverity = 0
$script:hkMediumSeverity = 0
$script:hkLowSeverity = 0
$script:hkCategories = 0
$script:hkFindings = @()

# Task 12.2: Check Administrator privileges
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  Honeybadger - Windows ISO27001 Compliance Audit" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$script:isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $script:isAdmin) {
    Write-Host "WARNING: Not running as Administrator!" -ForegroundColor Yellow
    Write-Host "Some checks will be unavailable:" -ForegroundColor Yellow
    Write-Host "  - BitLocker status" -ForegroundColor Yellow
    Write-Host "  - Windows Defender status (may be limited)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "For complete audit, run with Administrator privileges." -ForegroundColor Yellow
    Write-Host ""
}

# Task 1.3 & 12.3: Create report directory
Write-Host "[*] Creating report directory: $reportDir" -ForegroundColor Green
try {
    if (-not (Test-Path $reportDir)) {
        New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
    }
    if (-not (Test-Path $reportDir)) {
        throw "Failed to create report directory"
    }
} catch {
    Write-Host "ERROR: Could not create report directory: $_" -ForegroundColor Red
    exit 1
}

# Task 2.2: Collect hostname and username
Write-Host "[*] Collecting system information..." -ForegroundColor Green
$script:hostname = $env:COMPUTERNAME
$script:username = $env:USERNAME

# Task 2.3: Collect hardware serial number
try {
    $bios = Get-CimInstance Win32_BIOS -ErrorAction Stop
    $serial = $bios.SerialNumber

    # VM detection
    if ([string]::IsNullOrWhiteSpace($serial) -or
        $serial -match "To Be Filled|O\.E\.M\.|Default string|Not Specified|System Serial Number|^0+$") {
        $script:serialNumber = "Not available (VM or unknown hardware)"
    } else {
        $script:serialNumber = $serial
    }
} catch {
    $script:serialNumber = "Unable to retrieve (Error: $_)"
}

# Task 2.1 & 2.4: Collect OS version with neofetch or WMI
$neofetchPath = Get-Command neofetch -ErrorAction SilentlyContinue
if ($neofetchPath) {
    try {
        neofetch --stdout | Out-File "$reportDir\neofetch.txt" -Encoding UTF8
        $script:osVersion = "See neofetch.txt for details"
    } catch {
        $script:osVersion = "Neofetch failed"
    }
} else {
    Write-Host "[*] Neofetch not found, attempting to install via winget..." -ForegroundColor Yellow
    try {
        $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetPath) {
            winget install neofetch --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
            Start-Sleep -Seconds 2
            $neofetchPath = Get-Command neofetch -ErrorAction SilentlyContinue
            if ($neofetchPath) {
                neofetch --stdout | Out-File "$reportDir\neofetch.txt" -Encoding UTF8
                $script:osVersion = "See neofetch.txt for details"
            }
        }
    } catch {
        # Silently continue if winget install fails
    }

    # Fall back to WMI if neofetch still unavailable
    if (-not $neofetchPath -or $script:osVersion -eq "") {
        try {
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            $script:osVersion = "$($os.Caption) Build $($os.BuildNumber)"
        } catch {
            $script:osVersion = "Unable to determine OS version"
        }
    }
}

# Task 3: BitLocker Encryption Collection
Write-Host "[*] Checking BitLocker encryption status..." -ForegroundColor Green
if ($script:isAdmin) {
    try {
        $bitlockerVolumes = Get-BitLockerVolume -ErrorAction Stop
        $cDrive = $bitlockerVolumes | Where-Object { $_.MountPoint -eq "C:" }

        if ($cDrive) {
            $status = $cDrive.VolumeStatus
            $encryptionPct = $cDrive.EncryptionPercentage
            $protectionStatus = $cDrive.ProtectionStatus
            $keyProtector = ($cDrive.KeyProtector | ForEach-Object { $_.KeyProtectorType }) -join ", "

            # Task 3.3 & 3.4: Parse and determine compliance
            if ($status -eq "FullyEncrypted" -and $encryptionPct -eq 100 -and $protectionStatus -eq "On") {
                $script:bitlockerCompliant = $true
                $script:bitlockerStatus = "✅"
                $script:bitlockerDetails = "Fully encrypted ($encryptionPct%) - Key Protectors: $keyProtector - Protection: $protectionStatus"
            } elseif ($status -eq "FullyEncrypted" -and $encryptionPct -eq 100 -and $protectionStatus -ne "On") {
                $script:bitlockerCompliant = $false
                $script:bitlockerStatus = "❌"
                $script:bitlockerDetails = "Encrypted but protection is $protectionStatus (should be On) - BitLocker is suspended!"
            } else {
                $script:bitlockerCompliant = $false
                $script:bitlockerStatus = "❌"
                $script:bitlockerDetails = "Status: $status ($encryptionPct%) - Protection: $protectionStatus - Not fully encrypted or protected"
            }

            # Task 3.5: Save BitLocker output
            $bitlockerVolumes | Out-File "$reportDir\bitlocker_result.txt" -Encoding UTF8
        } else {
            $script:bitlockerStatus = "❌"
            $script:bitlockerDetails = "C: drive not found or BitLocker not enabled"
        }
    } catch {
        $script:bitlockerStatus = "❌"
        $script:bitlockerDetails = "Unable to check BitLocker - Administrator privileges required"
    }
} else {
    $script:bitlockerStatus = "❌"
    $script:bitlockerDetails = "Administrator privileges required"
}

# Task 4: Screen Lock Settings Collection
Write-Host "[*] Collecting screen lock settings..." -ForegroundColor Green

# Task 4.1: Screensaver settings
try {
    $script:screenSaveTimeOut = (Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name ScreenSaveTimeOut -ErrorAction SilentlyContinue).ScreenSaveTimeOut
    $script:screenSaveActive = (Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name ScreenSaveActive -ErrorAction SilentlyContinue).ScreenSaveActive
    $script:screenSaverSecure = (Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name ScreenSaverIsSecure -ErrorAction SilentlyContinue).ScreenSaverIsSecure
} catch {
    # Silently continue if registry keys don't exist
}

# Task 4.2: Power settings
try {
    # Language-independent parsing: find AC power setting line containing hex value
    $monitorTimeoutOutput = powercfg /q SCHEME_CURRENT SUB_VIDEO VIDEOIDLE 2>&1 | Select-String "AC.*0x"
    if ($monitorTimeoutOutput) {
        $script:monitorTimeout = ([regex]::Match($monitorTimeoutOutput.ToString(), "0x([0-9a-f]+)")).Groups[1].Value
        $script:monitorTimeout = [Convert]::ToInt32($script:monitorTimeout, 16)
    }

    $systemSleepOutput = powercfg /q SCHEME_CURRENT SUB_SLEEP STANDBYIDLE 2>&1 | Select-String "AC.*0x"
    if ($systemSleepOutput) {
        $script:systemSleep = ([regex]::Match($systemSleepOutput.ToString(), "0x([0-9a-f]+)")).Groups[1].Value
        $script:systemSleep = [Convert]::ToInt32($script:systemSleep, 16)
    }
} catch {
    # Silently continue if powercfg fails
}

# Task 4.3: Lock policy settings
try {
    $script:lockOnSleep = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name NoLockScreen -ErrorAction SilentlyContinue).NoLockScreen
} catch {
    # Silently continue
}

# Task 4.4: Require password on wake
try {
    $script:requirePasswordOnWake = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings" -Name ACSettingIndex -ErrorAction SilentlyContinue).ACSettingIndex
} catch {
    # Silently continue
}

# Task 4.5: Inactivity timeout
try {
    $script:inactivityTimeout = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name InactivityTimeoutSecs -ErrorAction SilentlyContinue).InactivityTimeoutSecs
} catch {
    # Silently continue
}

# Task 4.6 & 4.7: Evaluate screen lock compliance
if ($script:screenSaveTimeOut -and $script:screenSaveActive -eq "1" -and $script:screenSaverSecure -eq "1") {
    if ([int]$script:screenSaveTimeOut -le 900) {
        $script:screenLockCompliant = $true
        $script:screenLockDetails = "✅ Screensaver configured correctly ($([int]$script:screenSaveTimeOut / 60) minutes)"
    } else {
        $script:screenLockCompliant = $false
        $script:screenLockDetails = "❌ Screensaver timeout too long ($([int]$script:screenSaveTimeOut / 60) minutes, should be ≤15)"
    }
} else {
    $script:screenLockCompliant = $false
    $script:screenLockDetails = "❌ Screensaver not properly configured (inactive, no password, or not set)"
}

# Task 5: Windows Firewall Collection
Write-Host "[*] Checking Windows Firewall status..." -ForegroundColor Green
try {
    # Task 5.1 & 5.2: Get firewall profiles using language-independent profile type filtering
    # Get all profiles at once
    $firewallProfiles = Get-NetFirewallProfile -ErrorAction Stop

    # Filter by profile type (not localized name) - use array index or Profile property
    # Profiles are returned in consistent order: Domain(0), Private(1), Public(2)
    $domainProfile = $null
    $privateProfile = $null
    $publicProfile = $null

    foreach ($profile in $firewallProfiles) {
        switch -Regex ($profile.Name) {
            '^(Domain|Domein|Domaine|Domäne)$' { $domainProfile = $profile }
            '^(Private|Privé|Privat|Privado)$' { $privateProfile = $profile }
            '^(Public|Openbaar|Publique|Öffentlich|Público)$' { $publicProfile = $profile }
        }
    }

    $script:firewallDomain = $domainProfile.Enabled
    $script:firewallPrivate = $privateProfile.Enabled
    $script:firewallPublic = $publicProfile.Enabled

    # Task 5.3 & 5.4: Determine compliance
    if ($script:firewallDomain -and $script:firewallPrivate -and $script:firewallPublic) {
        $script:firewallCompliant = $true
        $script:firewallDetails = "✅ All profiles enabled (Domain, Private, Public)"
    } else {
        $disabledProfiles = @()
        if (-not $script:firewallDomain) { $disabledProfiles += "Domain" }
        if (-not $script:firewallPrivate) { $disabledProfiles += "Private" }
        if (-not $script:firewallPublic) { $disabledProfiles += "Public" }

        $script:firewallCompliant = $false
        $script:firewallDetails = "❌ Disabled profiles: $($disabledProfiles -join ', ')"
    }
} catch {
    # Fall back to registry if cmdlet unavailable
    try {
        $script:firewallDomain = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile" -Name EnableFirewall).EnableFirewall -eq 1
        $script:firewallPrivate = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\StandardProfile" -Name EnableFirewall).EnableFirewall -eq 1
        $script:firewallPublic = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\PublicProfile" -Name EnableFirewall).EnableFirewall -eq 1

        if ($script:firewallDomain -and $script:firewallPrivate -and $script:firewallPublic) {
            $script:firewallCompliant = $true
            $script:firewallDetails = "✅ All profiles enabled (via registry check)"
        } else {
            $script:firewallCompliant = $false
            $script:firewallDetails = "❌ One or more profiles disabled (via registry check)"
        }
    } catch {
        $script:firewallDetails = "Unable to determine firewall status"
    }
}

# Task 6: Windows Update Collection
Write-Host "[*] Checking Windows Update status..." -ForegroundColor Green
try {
    # Task 6.1 & 6.2: Get most recent hotfix
    $hotfixes = Get-HotFix -ErrorAction Stop | Sort-Object -Property InstalledOn -Descending
    if ($hotfixes.Count -gt 0) {
        $lastUpdate = $hotfixes[0]
        $script:lastUpdateKB = $lastUpdate.HotFixID
        $script:lastUpdateDate = $lastUpdate.InstalledOn

        # Task 6.3: Calculate days since update
        if ($script:lastUpdateDate) {
            $script:lastUpdateDaysAgo = ((Get-Date) - $script:lastUpdateDate).Days

            # Task 6.4: Determine compliance
            if ($script:lastUpdateDaysAgo -lt 14) {
                $script:updateCompliant = "✅"
                $script:updateDetails = "Last update: $($script:lastUpdateKB) on $($script:lastUpdateDate.ToString('yyyy-MM-dd')) ($script:lastUpdateDaysAgo days ago)"
            } elseif ($script:lastUpdateDaysAgo -le 30) {
                $script:updateCompliant = "⚠️"
                $script:updateDetails = "Last update: $($script:lastUpdateKB) on $($script:lastUpdateDate.ToString('yyyy-MM-dd')) ($script:lastUpdateDaysAgo days ago) - UPDATE RECOMMENDED"
            } else {
                $script:updateCompliant = "❌"
                $script:updateDetails = "Last update: $($script:lastUpdateKB) on $($script:lastUpdateDate.ToString('yyyy-MM-dd')) ($script:lastUpdateDaysAgo days ago) - UPDATE REQUIRED"
            }
        } else {
            # Task 6.5: Handle no date available
            $script:updateCompliant = "❌"
            $script:updateDetails = "Unable to determine last update date"
        }
    } else {
        $script:updateCompliant = "❌"
        $script:updateDetails = "No update history found"
    }
} catch {
    $script:updateCompliant = "❌"
    $script:updateDetails = "Unable to check update status: $_"
}

# Task 7: Windows Defender Collection
Write-Host "[*] Checking Windows Defender status..." -ForegroundColor Green
try {
    # Task 7.1 & 7.2: Get Defender status
    $mpStatus = Get-MpComputerStatus -ErrorAction Stop

    $script:defenderEnabled = $mpStatus.RealTimeProtectionEnabled
    $script:defenderSignatureVersion = $mpStatus.AntivirusSignatureVersion
    $script:defenderSignatureDate = $mpStatus.AntivirusSignatureLastUpdated

    # Task 7.3: Calculate days since definition update
    if ($script:defenderSignatureDate) {
        $script:defenderDaysOld = ((Get-Date) - $script:defenderSignatureDate).Days
    }

    # Task 7.4 & 7.5: Determine compliance
    if ($script:defenderEnabled -and $script:defenderDaysOld -lt 7) {
        $script:defenderCompliant = $true
        $script:defenderDetails = "✅ Enabled, definitions updated $script:defenderDaysOld days ago (version $script:defenderSignatureVersion)"
    } elseif ($script:defenderEnabled -and $script:defenderDaysOld -ge 7) {
        $script:defenderCompliant = $false
        $script:defenderDetails = "❌ Enabled but definitions outdated ($script:defenderDaysOld days old)"
    } else {
        $script:defenderCompliant = $false
        $script:defenderDetails = "❌ Real-time protection disabled"
    }
} catch {
    $script:defenderDetails = "Unable to check Windows Defender - may be disabled or third-party antivirus in use"
}

# Task 8: HardeningKitty Audit Execution
Write-Host "[*] Running HardeningKitty security audit..." -ForegroundColor Green
Write-Host "    (This may take a few minutes)" -ForegroundColor Gray

try {
    # Task 8.1: Import HardeningKitty module
    Import-Module ".\HardeningKitty\HardeningKitty.psm1" -ErrorAction Stop

    # Task 8.2: Run HardeningKitty
    Invoke-HardeningKitty -Mode Config -Report -ReportFile "$reportDir\hardeningkitty.csv" -SkipMachineInformation | Out-Null

    # Task 8.3: Verify CSV was created
    if (Test-Path "$reportDir\hardeningkitty.csv") {
        $fileSize = (Get-Item "$reportDir\hardeningkitty.csv").Length
        if ($fileSize -eq 0) {
            throw "HardeningKitty CSV is empty"
        }
    } else {
        throw "HardeningKitty CSV not created"
    }
} catch {
    Write-Host "WARNING: HardeningKitty audit failed: $_" -ForegroundColor Yellow
    Write-Host "Continuing with other checks..." -ForegroundColor Yellow
}

# Task 9: HardeningKitty Results Parsing
if (Test-Path "$reportDir\hardeningkitty.csv") {
    Write-Host "[*] Parsing HardeningKitty results..." -ForegroundColor Green

    try {
        # Task 9.1: Import CSV
        $hkData = Import-Csv "$reportDir\hardeningkitty.csv"

        # Task 9.2: Calculate total checks
        $script:hkTotalChecks = $hkData.Count

        # Task 9.3: Filter failed checks
        $failedChecks = $hkData | Where-Object {
            $_.Result -ne $_.Recommended -and
            -not [string]::IsNullOrWhiteSpace($_.Result) -and
            -not [string]::IsNullOrWhiteSpace($_.Recommended)
        }

        # Task 9.4: Group by severity (default to Low if empty)
        $highSeverity = $failedChecks | Where-Object { $_.Severity -eq "High" }
        $mediumSeverity = $failedChecks | Where-Object { $_.Severity -eq "Medium" }
        $lowSeverity = $failedChecks | Where-Object { $_.Severity -eq "Low" -or [string]::IsNullOrWhiteSpace($_.Severity) }

        $script:hkHighSeverity = $highSeverity.Count
        $script:hkMediumSeverity = $mediumSeverity.Count
        $script:hkLowSeverity = $lowSeverity.Count
        $script:hkFailedChecks = $failedChecks.Count

        # Task 9.5: Count passed checks
        $script:hkPassedChecks = $script:hkTotalChecks - $script:hkFailedChecks

        # Task 9.6: Get unique categories
        $script:hkCategories = ($hkData | Select-Object -ExpandProperty Category -Unique).Count

        # Task 9.7: Store findings for report generation
        $script:hkFindings = @{
            High = $highSeverity
            Medium = $mediumSeverity
            Low = $lowSeverity
        }
    } catch {
        Write-Host "WARNING: Failed to parse HardeningKitty results: $_" -ForegroundColor Yellow
    }
}

# Task 10: Compliance Report Generation
Write-Host "[*] Generating compliance report..." -ForegroundColor Green

$reportFilename = "honeybadger-$script:username-$timestamp-compliance.md"
$reportPath = Join-Path $reportDir $reportFilename

# Task 10.1-10.9: Create compliance report with all sections
$complianceReport = @"
# ISO27001 Compliance Report - Windows

**System**: $script:hostname
**User**: $script:username
**Date**: $script:reportDate
**Serial Number**: $script:serialNumber
**OS Version**: $script:osVersion

---

## Compliance Checklist

| Control | Status | Details |
|---------|--------|---------|
| **Disk Encryption** | $script:bitlockerStatus | $script:bitlockerDetails |
| **Screen Lock** | $(if($script:screenLockCompliant){'✅'}else{'❌'}) | $script:screenLockDetails |
| **Firewall** | $(if($script:firewallCompliant){'✅'}else{'❌'}) | $script:firewallDetails |
| **OS Updates** | $script:updateCompliant | $script:updateDetails |
| **Antivirus** | $(if($script:defenderCompliant){'✅'}else{'❌'}) | $script:defenderDetails |

---

## Screen Lock Configuration

### Screensaver Settings
- **Timeout**: $(if($script:screenSaveTimeOut){"$([int]$script:screenSaveTimeOut) seconds ($([Math]::Round([int]$script:screenSaveTimeOut / 60, 1)) minutes)"}else{"Not configured"})
- **Active**: $(if($script:screenSaveActive -eq "1"){"Yes"}elseif($script:screenSaveActive -eq "0"){"No"}else{"Not configured"})
- **Password Required**: $(if($script:screenSaverSecure -eq "1"){"Yes"}elseif($script:screenSaverSecure -eq "0"){"No"}else{"Not configured"})

### Power Management
- **Display Timeout**: $(if($script:monitorTimeout){"$([Math]::Round($script:monitorTimeout / 60, 1)) minutes"}else{"Not configured"})
- **System Sleep**: $(if($script:systemSleep){"$([Math]::Round($script:systemSleep / 60, 1)) minutes"}else{"Not configured"})

### Lock Policies
- **Lock Screen Disabled**: $(if($script:lockOnSleep -eq 1){"Yes (policy enforced)"}elseif($script:lockOnSleep -eq 0){"No"}else{"Not configured"})
- **Require Password on Wake**: $(if($script:requirePasswordOnWake){"Yes (policy enforced)"}else{"Not configured"})
- **Inactivity Timeout**: $(if($script:inactivityTimeout){"$script:inactivityTimeout seconds ($([Math]::Round($script:inactivityTimeout / 60, 1)) minutes)"}else{"Not configured"})

---

## BitLocker Encryption

$script:bitlockerDetails

$(if(Test-Path "$reportDir\bitlocker_result.txt"){"See ``bitlocker_result.txt`` for detailed volume information."}else{""})

---

## Windows Firewall

**Profile Status:**
- **Domain Profile**: $(if($script:firewallDomain){"✅ Enabled"}else{"❌ Disabled"})
- **Private Profile**: $(if($script:firewallPrivate){"✅ Enabled"}else{"❌ Disabled"})
- **Public Profile**: $(if($script:firewallPublic){"✅ Enabled"}else{"❌ Disabled"})

---

## Windows Update Status

$script:updateDetails

**Compliance Thresholds:**
- ✅ Compliant: Updates installed within 14 days
- ⚠️ Warning: Updates 14-30 days old (update recommended)
- ❌ Non-Compliant: Updates >30 days old (update required)

---

## Windows Defender Antivirus

$script:defenderDetails

$(if($script:defenderSignatureDate){"**Last Definition Update**: $($script:defenderSignatureDate.ToString('yyyy-MM-dd HH:mm:ss'))"}else{""})

---

## HardeningKitty Security Audit

"@

if($script:hkTotalChecks -gt 0){
    $complianceReport += @"
**Total Checks**: $script:hkTotalChecks
**Passed**: $script:hkPassedChecks
**Failed**: $script:hkFailedChecks (High: $script:hkHighSeverity, Medium: $script:hkMediumSeverity, Low: $script:hkLowSeverity)
**Categories**: $script:hkCategories

See ``honeybadger-$script:username-$timestamp-actions.md`` for detailed remediation steps.
"@
}else{
    $complianceReport += "HardeningKitty audit was not completed. Check script output for errors."
}

$complianceReport += @"

---

## Report Generation

This report was generated automatically by Honeybadger.
For questions or issues, visit: https://github.com/wearetechnative/honeybadger

"@

# Task 10.10: Write compliance report
try {
    $complianceReport | Out-File -FilePath $reportPath -Encoding UTF8 -Force
    Write-Host "    ✓ Compliance report created: $reportPath" -ForegroundColor Green
} catch {
    Write-Host "    ERROR: Failed to write compliance report: $_" -ForegroundColor Red
}

# Task 11: Actions Report Generation
Write-Host "[*] Generating actions report..." -ForegroundColor Green

$actionsFilename = "honeybadger-$script:username-$timestamp-actions.md"
$actionsPath = Join-Path $reportDir $actionsFilename

# Task 11.1-11.6: Create actions report
$actionsReport = @"
# Security Actions - Windows

**System**: $script:hostname
**User**: $script:username
**Date**: $script:reportDate

---

"@

if($script:hkFailedChecks -gt 0){
    $actionsReport += @"
## Summary

Total failed security checks: **$script:hkFailedChecks**
- High Severity: $script:hkHighSeverity
- Medium Severity: $script:hkMediumSeverity
- Low Severity: $script:hkLowSeverity

---

## High Severity Issues ($script:hkHighSeverity items)

"@
    if($script:hkHighSeverity -gt 0){
        $actionsReport += ($script:hkFindings.High | ForEach-Object {
            "**[$($_.ID)]** $($_.Category): $($_.Name)  " +
            "- **Current**: $($_.Result)  " +
            "- **Recommended**: $($_.Recommended)  "
        }) -join "`n`n"
    }else{
        $actionsReport += "No high severity issues found."
    }

    $actionsReport += @"

---

## Medium Severity Issues ($script:hkMediumSeverity items)

"@
    if($script:hkMediumSeverity -gt 0){
        $actionsReport += ($script:hkFindings.Medium | ForEach-Object {
            "**[$($_.ID)]** $($_.Category): $($_.Name)  " +
            "- **Current**: $($_.Result)  " +
            "- **Recommended**: $($_.Recommended)  "
        }) -join "`n`n"
    }else{
        $actionsReport += "No medium severity issues found."
    }

    $actionsReport += @"

---

## Low Severity Issues ($script:hkLowSeverity items)

"@
    if($script:hkLowSeverity -gt 0){
        $actionsReport += ($script:hkFindings.Low | ForEach-Object {
            "**[$($_.ID)]** $($_.Category): $($_.Name)  " +
            "- **Current**: $($_.Result)  " +
            "- **Recommended**: $($_.Recommended)  "
        }) -join "`n`n"
    }else{
        $actionsReport += "No low severity issues found."
    }
}else{
    $actionsReport += @"
## All Security Checks Passed ✅

Congratulations! All HardeningKitty security checks passed.
No remediation actions are required at this time.
"@
}

$actionsReport += @"

---

## Next Steps

1. Review failed checks by severity (High > Medium > Low)
2. Consult your organization's security policies for remediation guidance
3. Implement recommended settings via Group Policy or local configuration
4. Re-run audit after making changes: ``.\RUNME.ps1``

---

**Generated by Honeybadger**
https://github.com/wearetechnative/honeybadger
"@

# Task 11.7: Write actions report
try {
    $actionsReport | Out-File -FilePath $actionsPath -Encoding UTF8 -Force
    Write-Host "    ✓ Actions report created: $actionsPath" -ForegroundColor Green
} catch {
    Write-Host "    ERROR: Failed to write actions report: $_" -ForegroundColor Red
}

# Task 12.4 & 12.5: Verification and final success message
Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  Audit Complete!" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

if ((Test-Path $reportPath) -and (Test-Path $actionsPath)) {
    Write-Host "Reports generated successfully:" -ForegroundColor Green
    Write-Host "  - Compliance Report: $reportPath" -ForegroundColor White
    Write-Host "  - Actions Report: $actionsPath" -ForegroundColor White
    if (Test-Path "$reportDir\hardeningkitty.csv") {
        Write-Host "  - HardeningKitty Data: $reportDir\hardeningkitty.csv" -ForegroundColor White
    }
    Write-Host ""

    # Create ZIP archive
    Write-Host "[*] Creating ZIP archive..." -ForegroundColor Green
    $zipFileName = "honeybadger-$script:hostname-$script:username-$timestamp.zip"
    try {
        Compress-Archive -Path $reportDir -DestinationPath $zipFileName -Force
        if (Test-Path $zipFileName) {
            $zipSize = [math]::Round((Get-Item $zipFileName).Length / 1KB, 1)
            Write-Host "    ✓ ZIP archive created: $zipFileName ($zipSize KB)" -ForegroundColor Green
        }
    } catch {
        Write-Host "    WARNING: Failed to create ZIP archive: $_" -ForegroundColor Yellow
    }
    Write-Host ""

    Write-Host "Review the compliance report for ISO27001 compliance status." -ForegroundColor Green
} else {
    Write-Host "WARNING: One or more reports failed to generate." -ForegroundColor Yellow
    Write-Host "Check error messages above for details." -ForegroundColor Yellow
}
