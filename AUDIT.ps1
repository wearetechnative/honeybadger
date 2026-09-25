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

# The shared logic - the serial rule, the fastfetch parser, the inventory
# document, naming, submission classification - lives in a module so it can be
# tested under pwsh on a machine that is not Windows. This script collects from
# Windows; the module decides what the collected values mean.
$script:thisDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $script:thisDir "lib/Honeybadger.psm1") -Force -ErrorAction Stop

# Task 1.4: Global variables for collected data
$script:isAdmin = $false
$script:hostname = $env:COMPUTERNAME
$script:username = $env:USERNAME
$script:serialNumber = ""
$script:serialSource = ""
$script:serialStatus = ""
$script:osVersion = ""
$script:model = ""
$script:reportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$script:runDate = Get-Date

# Task 1.3: Output directory, named the way every other platform names one, so
# that check-output and the collection server read a Windows archive like any
# other. RUNME.sh:123 builds the same string.
$reportDir = Get-HbOutputDirectoryName $script:hostname $script:username $script:runDate
$script:archiveName = Get-HbArchiveName $script:hostname $script:username $script:runDate

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

# Task 2.3: Collect hardware serial number.
#
# The value goes to a file, because hardware-serial.txt is what lets the
# collection server attribute a submission to an asset in the ISO register - it
# used to reach the operator only inside the compliance markdown, which the
# server does not read. Whether the value counts as a serial is decided by the
# shared rule rather than by a regex local to this script: the placeholder this
# code used to store as the value, "Not available (VM or unknown hardware)", is
# in that rule's list and is not a measurement.
try {
    $bios = Get-CimInstance Win32_BIOS -ErrorAction Stop
    $serialResult = Resolve-HbSerial $bios.SerialNumber
} catch {
    $serialResult = Resolve-HbSerial -QueryFailed
}

$script:serialNumber = $serialResult.Value
$script:serialSource = $serialResult.Source
$script:serialStatus = $serialResult.Status

try {
    $serialResult.Value | Out-File "$reportDir\hardware-serial.txt" -Encoding UTF8
    if ($serialResult.IsUsable) {
        $serialResult.Source | Out-File "$reportDir\hardware-serial-source.txt" -Encoding UTF8
        Write-Host "    Found $($serialResult.Value) via $($serialResult.Source)" -ForegroundColor Gray
    } else {
        Write-Host "    No usable serial yet ($($serialResult.Status)) - details at the end of the run" -ForegroundColor Yellow
    }
} catch {
    Write-Host "WARNING: Could not write hardware-serial.txt: $_" -ForegroundColor Yellow
}

# Task 2.1 & 2.4: Collect system information with fastfetch.
#
# fastfetch.json is the only system-information format the client writes or
# reads, on every platform - see the system-information-collection capability.
# There is deliberately no fallback to Win32_OperatingSystem: a fastfetch.json
# assembled from another source, with some keys missing, is indistinguishable
# to a consumer from a machine where those values could not be read.
$fastfetchPath = Get-Command fastfetch -ErrorAction SilentlyContinue
if (-not $fastfetchPath) {
    Write-Host "[*] fastfetch not found, attempting to install via winget..." -ForegroundColor Yellow
    try {
        $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetPath) {
            winget install --id Fastfetch-cli.Fastfetch --silent `
                --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
            Start-Sleep -Seconds 2
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                        [System.Environment]::GetEnvironmentVariable("Path", "User")
            $fastfetchPath = Get-Command fastfetch -ErrorAction SilentlyContinue
        }
    } catch {
        # Reported below; a failed install is not a different outcome from absence.
    }
}

if ($fastfetchPath) {
    try {
        $fastfetchConfig = Join-Path $script:thisDir "lib/fastfetch-config-windows.jsonc"
        $fastfetchLines = & fastfetch --config $fastfetchConfig --logo none 2>$null
        $fastfetchData = ConvertTo-HbFastfetchJson $fastfetchLines

        if ($fastfetchData.Count -eq 0) {
            throw "fastfetch produced no parseable output"
        }

        $fastfetchData | ConvertTo-Json -Depth 4 |
            Out-File "$reportDir\fastfetch.json" -Encoding UTF8

        if ($fastfetchData.Contains("os")) { $script:osVersion = $fastfetchData["os"] }
        if ($fastfetchData.Contains("host")) { $script:model = $fastfetchData["host"] }
    } catch {
        Write-Host "ERROR: fastfetch ran but its output could not be used: $_" -ForegroundColor Red
        Write-Host "  fastfetch.json is the only system information format this client writes." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host ""
    Write-Host "ERROR: fastfetch is required and could not be found or installed." -ForegroundColor Red
    Write-Host "  Install it with:  winget install Fastfetch-cli.Fastfetch" -ForegroundColor Red
    Write-Host "  or see https://github.com/fastfetch-cli/fastfetch" -ForegroundColor Red
    Write-Host ""
    exit 1
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
# The same 900-second limit the Linux client applies. The detail names the limit
# and the registry values the verdict rests on, so the finding can be traced
# without reading this script.
$script:screenLockLimitSeconds = 900
$screenLockBasis = "limit $script:screenLockLimitSeconds s; " +
    "ScreenSaveTimeOut=$(if($null -ne $script:screenSaveTimeOut){$script:screenSaveTimeOut}else{'not set'}), " +
    "ScreenSaveActive=$(if($null -ne $script:screenSaveActive){$script:screenSaveActive}else{'not set'}), " +
    "ScreenSaverIsSecure=$(if($null -ne $script:screenSaverSecure){$script:screenSaverSecure}else{'not set'})"
if ($script:screenSaveTimeOut -and $script:screenSaveActive -eq "1" -and $script:screenSaverSecure -eq "1") {
    if ([int]$script:screenSaveTimeOut -le $script:screenLockLimitSeconds) {
        $script:screenLockCompliant = $true
        $script:screenLockDetails = "✅ Screensaver configured correctly ($([int]$script:screenSaveTimeOut / 60) minutes; $screenLockBasis)"
    } else {
        $script:screenLockCompliant = $false
        $script:screenLockDetails = "❌ Screensaver timeout too long ($([int]$script:screenSaveTimeOut / 60) minutes, should be ≤15; $screenLockBasis)"
    }
} else {
    $script:screenLockCompliant = $false
    $script:screenLockDetails = "❌ Screensaver not properly configured (inactive, no password, or not set; $screenLockBasis)"
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

    # Task 7.4 & 7.5: Determine compliance. Definitions must be under 7 days old.
    $script:defenderMaxAgeDays = 7
    if ($script:defenderEnabled -and $script:defenderDaysOld -lt $script:defenderMaxAgeDays) {
        $script:defenderCompliant = $true
        $script:defenderDetails = "✅ Enabled, definitions updated $script:defenderDaysOld days ago (limit: under $script:defenderMaxAgeDays days; version $script:defenderSignatureVersion)"
    } elseif ($script:defenderEnabled -and $script:defenderDaysOld -ge $script:defenderMaxAgeDays) {
        $script:defenderCompliant = $false
        $script:defenderDetails = "❌ Enabled but definitions outdated ($script:defenderDaysOld days old, limit: under $script:defenderMaxAgeDays days)"
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

$reportFilename = Get-HbReportName $script:username "compliance" $script:runDate
$reportPath = Join-Path $reportDir $reportFilename
# Named here as well as where it is written, because the compliance report
# points the reader at it.
$actionsFilename = Get-HbReportName $script:username "actions" $script:runDate

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

A passing verdict requires a timeout of at most 900 seconds (15 minutes), an active screensaver, and
a password on resume (``ScreenSaverIsSecure = 1``). The password requirement is specific to this
platform: Windows records it in the registry, where the Linux client has no equivalent setting to read.

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

See ``$actionsFilename`` for detailed remediation steps.
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

# Task 11.8: Machine-readable asset inventory.
#
# The counterpart of the two markdown reports, in the shape the collection
# server reads. Built from the determinations made above rather than by
# evaluating the collected data a second time - whether BitLocker counts as
# encryption is platform knowledge, and a second implementation of these rules
# would drift from the first.
Write-Host "[*] Writing machine-readable asset inventory..." -ForegroundColor Green
try {
    $osUptodateCell = switch ($script:updateCompliant) {
        "✅" { "Yes" }
        "⚠️" { "Yes" }
        default { "No" }
    }

    $findings = [ordered]@{
        os = New-HbFinding $script:osVersion $script:osVersion
        disk_encryption = New-HbFinding `
            $(if ($script:bitlockerCompliant) { "Yes" } else { "No" }) `
            $script:bitlockerDetails
        screen_lock = New-HbFinding `
            $(if ($script:screenLockCompliant) { "Yes" } else { "No" }) `
            $script:screenLockDetails
        firewall = New-HbFinding `
            $(if ($script:firewallCompliant) { "Yes" } else { "No" }) `
            $script:firewallDetails
        antivirus = New-HbFinding `
            $(if ($script:defenderCompliant) { "Yes" } else { "No" }) `
            $script:defenderDetails
        # Windows has no package audit tool in this client's dependency set, so
        # nothing was counted. A null count is "nothing looked", which is not
        # the same as a measured zero.
        vulnerable_packages = New-HbFinding "" `
            "not determined - no package audit tool present on Windows" "count" $null
        hardening_score = New-HbHardeningScoreFinding `
            -TotalChecks $script:hkTotalChecks `
            -PassedChecks $script:hkPassedChecks `
            -HighSeverity $script:hkHighSeverity `
            -MediumSeverity $script:hkMediumSeverity `
            -LowSeverity $script:hkLowSeverity
        os_uptodate = New-HbFinding $osUptodateCell $script:updateDetails
    }

    $honeybadgerVersion = "unknown"
    $versionFile = Join-Path $script:thisDir "VERSION-honeybadger"
    if (Test-Path $versionFile) {
        $honeybadgerVersion = (Get-Content $versionFile -Raw).Trim()
    }

    $inventory = New-HbAssetInventory `
        -Hostname $script:hostname `
        -Username $script:username `
        -ScanDate $script:reportDate `
        -Serial $script:serialNumber `
        -Model $script:model `
        -Findings $findings `
        -HoneybadgerVersion $honeybadgerVersion

    ConvertTo-HbInventoryJson $inventory |
        Out-File "$reportDir\asset-inventory.json" -Encoding UTF8

    Write-Host "    ✓ Machine-readable asset inventory: $reportDir\asset-inventory.json" -ForegroundColor Green
} catch {
    Write-Host "    ERROR: Failed to write asset-inventory.json: $_" -ForegroundColor Red
}

# Task 12.4 & 12.5: Verification and final success message
Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  Audit Complete!" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

# The serial is the key the collection server matches an asset on, so an audit
# that determined none says so where the operator is looking, rather than
# completing silently and being noticed weeks later in the register.
if ($script:serialStatus -ne "ok") {
    Write-Host "Hardware serial: none determined" -ForegroundColor Yellow
    if ($script:serialStatus -eq (Get-HbSerialNotPresent)) {
        Write-Host "  The firmware reports no serial, which a virtual machine legitimately does." -ForegroundColor Yellow
        Write-Host "  hardware-serial.txt contains '$($script:serialNumber)'." -ForegroundColor Yellow
    } else {
        Write-Host "  Win32_BIOS could not be queried, so nothing was read." -ForegroundColor Yellow
        Write-Host "  hardware-serial.txt contains '$($script:serialNumber)'." -ForegroundColor Yellow
    }
    Write-Host "  The collection server resolves an asset by serial; this submission will need" -ForegroundColor Yellow
    Write-Host "  the hostname to be matched by hand." -ForegroundColor Yellow
    Write-Host ""
}

if ((Test-Path $reportPath) -and (Test-Path $actionsPath)) {
    Write-Host "Reports generated successfully:" -ForegroundColor Green
    Write-Host "  - Compliance Report: $reportPath" -ForegroundColor White
    Write-Host "  - Actions Report: $actionsPath" -ForegroundColor White
    if (Test-Path "$reportDir\hardeningkitty.csv") {
        Write-Host "  - HardeningKitty Data: $reportDir\hardeningkitty.csv" -ForegroundColor White
    }
    Write-Host ""

    # Create the tar archive.
    #
    # tar, not zip: the collection server's archive endpoint is what carries the
    # hardware serial, and a zip cannot be submitted to it. tar.exe is bsdtar
    # and has shipped with Windows since 10 build 17063, so this needs nothing
    # installed.
    Write-Host "[*] Creating tar archive..." -ForegroundColor Green
    $tarFileName = $script:archiveName
    try {
        $tarPath = Get-Command tar -ErrorAction SilentlyContinue
        if (-not $tarPath) {
            throw "tar was not found on PATH (Windows 10 build 17063 and later ship it)"
        }

        & tar -czf $tarFileName $reportDir
        if ($LASTEXITCODE -ne 0) {
            throw "tar exited with status $LASTEXITCODE"
        }

        if (Test-Path $tarFileName) {
            $tarSize = [math]::Round((Get-Item $tarFileName).Length / 1KB, 1)
            Write-Host "    ✓ Archive created: $tarFileName ($tarSize KB)" -ForegroundColor Green
            Write-Host "    Submit it with: .\submit-report.ps1" -ForegroundColor White
        } else {
            throw "tar reported success but no archive was written"
        }
    } catch {
        Write-Host "    ERROR: Failed to create the archive: $_" -ForegroundColor Red
        Write-Host "    The collected output is still in $reportDir and can be" -ForegroundColor Yellow
        Write-Host "    archived by hand: tar -czf $tarFileName $reportDir" -ForegroundColor Yellow
    }
    Write-Host ""

    Write-Host "Review the compliance report for ISO27001 compliance status." -ForegroundColor Green
} else {
    Write-Host "WARNING: One or more reports failed to generate." -ForegroundColor Yellow
    Write-Host "Check error messages above for details." -ForegroundColor Yellow
}
