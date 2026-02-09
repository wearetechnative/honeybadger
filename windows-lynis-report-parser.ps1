<#
.SYNOPSIS
    Script to parse Lynis report JSON and extract key security information for Windows systems
.DESCRIPTION
    This PowerShell script parses a Lynis JSON report and displays key security information
    including OS details, kernel information, secure boot settings, password policies,
    firewall status, encryption information, and update status.
.PARAMETER ReportFile
    Path to the Lynis JSON report file
.EXAMPLE
    .\windows-lynis-report-parser.ps1 -ReportFile "C:\path\to\lynis-report.json"
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$ReportFile
)

# Check if the report file exists
if (-not (Test-Path $ReportFile)) {
    Write-Error "Error: Report file not found: $ReportFile"
    exit 1
}

# Function to get JSON value safely
function Get-JsonValue {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$JsonData,
        
        [Parameter(Mandatory = $true)]
        [string]$Key,
        
        [Parameter(Mandatory = $false)]
        [string]$Default = "Unknown"
    )
    
    if ($null -ne $JsonData.$Key -and $JsonData.$Key -ne "NA") {
        return $JsonData.$Key
    }
    else {
        return $Default
    }
}

# Read and parse the JSON file
try {
    $jsonContent = Get-Content -Path $ReportFile -Raw | ConvertFrom-Json
}
catch {
    Write-Error "Error parsing JSON file: $_"
    exit 1
}

# Display System Information
Write-Host "===== SYSTEM INFORMATION =====" -ForegroundColor Cyan
Write-Host "OS Name:           $(Get-JsonValue -JsonData $jsonContent -Key 'os_name')"
Write-Host "OS Full Name:      $(Get-JsonValue -JsonData $jsonContent -Key 'os_fullname')"
Write-Host "OS Version:        $(Get-JsonValue -JsonData $jsonContent -Key 'os_version')"
Write-Host ""

# Display Kernel Information
Write-Host "===== KERNEL INFORMATION =====" -ForegroundColor Cyan
Write-Host "Kernel Version:    $(Get-JsonValue -JsonData $jsonContent -Key 'linux_kernel_version')"
Write-Host "Kernel Release:    $(Get-JsonValue -JsonData $jsonContent -Key 'linux_kernel_release')"
Write-Host "Kernel Full:       $(Get-JsonValue -JsonData $jsonContent -Key 'os_kernel_version_full')"
Write-Host "Kernel Type:       $(Get-JsonValue -JsonData $jsonContent -Key 'linux_kernel_type')"
Write-Host ""

# Display Boot Security
Write-Host "===== BOOT SECURITY =====" -ForegroundColor Cyan
Write-Host "Boot Loader:       $(Get-JsonValue -JsonData $jsonContent -Key 'boot_loader')"
Write-Host "UEFI Boot:         $(Get-JsonValue -JsonData $jsonContent -Key 'boot_uefi_booted')"
$secureBootValue = Get-JsonValue -JsonData $jsonContent -Key 'boot_uefi_booted_secure'
Write-Host "Secure Boot:       $secureBootValue (0=disabled, 1=enabled)"
Write-Host ""

# Display Password Settings
Write-Host "===== PASSWORD SETTINGS =====" -ForegroundColor Cyan
Write-Host "Min Password Age:  $(Get-JsonValue -JsonData $jsonContent -Key 'password_min_days')"
Write-Host "Max Password Age:  $(Get-JsonValue -JsonData $jsonContent -Key 'password_max_days')"
Write-Host ""

# Display Firewall Status
Write-Host "===== FIREWALL STATUS =====" -ForegroundColor Cyan
Write-Host "Firewall Installed: $(Get-JsonValue -JsonData $jsonContent -Key 'firewall_installed') (0=no, 1=yes)"
Write-Host "Firewall Active:    $(Get-JsonValue -JsonData $jsonContent -Key 'firewall_active') (0=no, 1=yes)"

# Handle firewall software safely
Write-Host -NoNewline "Firewall Software:  "
if ($null -ne $jsonContent.firewall_software -and $jsonContent.firewall_software.Count -gt 0) {
    Write-Host $jsonContent.firewall_software -join ", "
}
else {
    Write-Host "None detected"
}

Write-Host "Empty Ruleset:      $(Get-JsonValue -JsonData $jsonContent -Key 'firewall_empty_ruleset') (0=no, 1=yes)"
Write-Host ""

# Display Encryption Information
Write-Host "===== ENCRYPTION =====" -ForegroundColor Cyan
Write-Host "Encryption Methods:"
if ($null -ne $jsonContent.encryption -and $jsonContent.encryption.Count -gt 0) {
    foreach ($item in $jsonContent.encryption) {
        Write-Host "- $item"
    }
}
else {
    Write-Host "- None detected"
}

Write-Host "Encrypted Swap:"
if ($null -ne $jsonContent.encrypted_swap -and $jsonContent.encrypted_swap.Count -gt 0) {
    foreach ($item in $jsonContent.encrypted_swap) {
        Write-Host "- $item"
    }
}
else {
    Write-Host "- None detected"
}
Write-Host ""

# Display System Updates
Write-Host "===== SYSTEM UPDATES =====" -ForegroundColor Cyan
Write-Host "Package Audit Tool: $(Get-JsonValue -JsonData $jsonContent -Key 'package_audit_tool_found') (0=no, 1=yes)"
Write-Host "Vulnerable Packages Found: $(Get-JsonValue -JsonData $jsonContent -Key 'vulnerable_packages_found') (0=no, 1=yes)"
Write-Host "Unattended Upgrades Available: $(Get-JsonValue -JsonData $jsonContent -Key 'unattended_upgrade_option_available') (0=no, 1=yes)"

# Check for update-related suggestions
$updateSuggestions = @()
if ($null -ne $jsonContent.suggestion) {
    $updateSuggestions = $jsonContent.suggestion | Where-Object {
        $_.description -match "update|upgrade|patch"
    }
}

if ($updateSuggestions.Count -gt 0) {
    Write-Host "Update-related suggestions found:"
    foreach ($suggestion in $updateSuggestions) {
        Write-Host "- $($suggestion.description)"
    }
}
else {
    Write-Host "No update-related suggestions found"
}

# Report scan date
Write-Host "Scan performed on: $(Get-JsonValue -JsonData $jsonContent -Key 'report_datetime_end')"
Write-Host ""

# Display System Hardening
Write-Host "===== SYSTEM HARDENING =====" -ForegroundColor Cyan
Write-Host "Hardening Index: $(Get-JsonValue -JsonData $jsonContent -Key 'hardening_index')/100"
Write-Host ""

Write-Host "Report generated on: $(Get-Date)"

# Add Windows-specific information
Write-Host ""
Write-Host "===== WINDOWS SPECIFIC INFORMATION =====" -ForegroundColor Cyan
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
Write-Host "Windows Version:    $($osInfo.Caption)"
Write-Host "Windows Build:      $($osInfo.BuildNumber)"
Write-Host "Last Boot Time:     $($osInfo.LastBootUpTime)"

# Get Windows Update information
try {
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher = $updateSession.CreateUpdateSearcher()
    $searchResult = $updateSearcher.Search("IsInstalled=1")
    $lastUpdate = $searchResult.Updates | Sort-Object -Property LastDeploymentChangeTime -Descending | Select-Object -First 1
    
    if ($null -ne $lastUpdate) {
        Write-Host "Last Windows Update: $($lastUpdate.LastDeploymentChangeTime)"
    }
    else {
        Write-Host "Last Windows Update: No update history found"
    }
}
catch {
    Write-Host "Last Windows Update: Unable to retrieve update information"
}

# Get Windows Defender status
try {
    $defenderStatus = Get-MpComputerStatus
    Write-Host ""
    Write-Host "===== WINDOWS DEFENDER STATUS =====" -ForegroundColor Cyan
    Write-Host "Real-time Protection: $($defenderStatus.RealTimeProtectionEnabled)"
    Write-Host "Antivirus Signature: $($defenderStatus.AntivirusSignatureVersion)"
    Write-Host "Last Scan Time:      $($defenderStatus.LastFullScanTime)"
    Write-Host "Definitions Updated: $($defenderStatus.AntivirusSignatureLastUpdated)"
}
catch {
    Write-Host ""
    Write-Host "===== WINDOWS DEFENDER STATUS =====" -ForegroundColor Cyan
    Write-Host "Unable to retrieve Windows Defender information"
}

# Get BitLocker status
try {
    $bitlockerVolumes = Get-BitLockerVolume
    Write-Host ""
    Write-Host "===== BITLOCKER ENCRYPTION STATUS =====" -ForegroundColor Cyan
    
    if ($null -ne $bitlockerVolumes) {
        foreach ($volume in $bitlockerVolumes) {
            Write-Host "Drive $($volume.MountPoint): $($volume.VolumeStatus) - $($volume.EncryptionMethod)"
        }
    }
    else {
        Write-Host "No BitLocker volumes found"
    }
}
catch {
    Write-Host ""
    Write-Host "===== BITLOCKER ENCRYPTION STATUS =====" -ForegroundColor Cyan
    Write-Host "Unable to retrieve BitLocker information"
}
