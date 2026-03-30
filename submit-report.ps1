#Requires -Version 5.1
<#
.SYNOPSIS
    Submit Honeybadger ZIP report to server
.DESCRIPTION
    Uploads the generated ZIP file to a configured server endpoint
.PARAMETER ZipFile
    Path to the ZIP file to upload (optional - auto-detects latest if not specified)
.EXAMPLE
    .\submit-report.ps1
    .\submit-report.ps1 -ZipFile honeybadger-LAPTOP-john-20260330.zip
#>

param(
    [string]$ZipFile = ""
)

# Load configuration
function Load-Configuration {
    $configLocations = @(
        ".\.honeybadger.conf",
        "$env:USERPROFILE\.honeybadger.conf",
        "C:\ProgramData\honeybadger.conf"
    )

    $config = @{
        SERVER_ENABLED = $false
        SERVER_URL = ""
        SERVER_TOKEN = ""
    }

    foreach ($configFile in $configLocations) {
        if (Test-Path $configFile) {
            Write-Host "Loading configuration from: $configFile" -ForegroundColor Gray
            $content = Get-Content $configFile
            foreach ($line in $content) {
                if ($line -match '^SERVER_ENABLED=(.+)$') {
                    $config.SERVER_ENABLED = ($matches[1] -eq 'true')
                }
                if ($line -match '^SERVER_URL=(.+)$') {
                    $config.SERVER_URL = $matches[1]
                }
                if ($line -match '^SERVER_TOKEN=(.+)$') {
                    $config.SERVER_TOKEN = $matches[1]
                }
            }
            break
        }
    }

    return $config
}

# Find latest ZIP file
function Find-LatestZip {
    $zips = Get-ChildItem -Filter "honeybadger-*.zip" | Sort-Object LastWriteTime -Descending
    if ($zips.Count -eq 0) {
        return $null
    }
    return $zips[0].FullName
}

# Main script
Write-Host "======================================"
Write-Host "Honeybadger Report Submission"
Write-Host "======================================"
Write-Host ""

# Load config
$config = Load-Configuration

if (-not $config.SERVER_ENABLED) {
    Write-Host "ERROR: Server submission is disabled (SERVER_ENABLED=false)" -ForegroundColor Red
    Write-Host ""
    Write-Host "To enable submission:"
    Write-Host "1. Copy .honeybadger.conf.example to .honeybadger.conf"
    Write-Host "2. Set SERVER_ENABLED=true"
    Write-Host "3. Configure SERVER_URL and SERVER_TOKEN"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($config.SERVER_URL)) {
    Write-Host "ERROR: SERVER_URL not configured" -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrWhiteSpace($config.SERVER_TOKEN)) {
    Write-Host "ERROR: SERVER_TOKEN not configured" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please add SERVER_TOKEN to your .honeybadger.conf file:"
    Write-Host "  SERVER_TOKEN=hb_token_your_token_here"
    exit 1
}

# Find ZIP file
if ([string]::IsNullOrWhiteSpace($ZipFile)) {
    Write-Host "No ZIP file specified, searching for latest..." -ForegroundColor Yellow
    $ZipFile = Find-LatestZip
    if ($null -eq $ZipFile) {
        Write-Host "ERROR: No honeybadger-*.zip files found" -ForegroundColor Red
        Write-Host ""
        Write-Host "Run audit first to generate a report:"
        Write-Host "  .\RUNME.cmd (or .\AUDIT.ps1)"
        exit 1
    }
    Write-Host "Found: $ZipFile" -ForegroundColor Green
}

if (-not (Test-Path $ZipFile)) {
    Write-Host "ERROR: ZIP file not found: $ZipFile" -ForegroundColor Red
    exit 1
}

# Get system info
$hostname = $env:COMPUTERNAME
$username = $env:USERNAME
$fileSize = [math]::Round((Get-Item $ZipFile).Length / 1KB, 1)

Write-Host ""
Write-Host "Uploading report..." -ForegroundColor Green
Write-Host "  File: $ZipFile ($fileSize KB)"
Write-Host "  Server: $config.SERVER_URL"
Write-Host "  Hostname: $hostname"
Write-Host "  Username: $username"
Write-Host ""

# Upload with Invoke-WebRequest
try {
    $headers = @{
        "Authorization" = "Bearer $($config.SERVER_TOKEN)"
        "X-Hostname" = $hostname
        "X-Username" = $username
        "X-Report-Type" = "windows-compliance"
    }

    $response = Invoke-WebRequest `
        -Uri $config.SERVER_URL `
        -Method Post `
        -Headers $headers `
        -InFile $ZipFile `
        -ContentType "application/zip" `
        -UseBasicParsing

    if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 201) {
        Write-Host "✓ Report uploaded successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Server response: $($response.StatusCode) $($response.StatusDescription)"
    } else {
        Write-Host "WARNING: Unexpected response code: $($response.StatusCode)" -ForegroundColor Yellow
    }

} catch {
    Write-Host "ERROR: Upload failed" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
