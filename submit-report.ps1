#Requires -Version 5.1
<#
.SYNOPSIS
    Submit a Honeybadger audit archive to the collection server.
.DESCRIPTION
    Uploads the tar archive produced by AUDIT.ps1 to SERVER_URL/submit-tar.

    The archive is the unit of submission because it carries hardware-serial.txt,
    which is what lets the server attribute the submission to an asset in the
    ISO register. The endpoint this script used to post a zip to has no concept
    of a hardware serial, so its submissions could not be attributed to
    anything - the same reason the Linux client was moved off that path.
.PARAMETER TarFile
    Path to the archive to upload. Defaults to the most recent one in the
    current directory.
.EXAMPLE
    .\submit-report.ps1
    .\submit-report.ps1 -TarFile honeybadger-LAPTOP-john-elma-15-09-2026.tar.gz
    $env:DRY_RUN = "true"; .\submit-report.ps1
#>

param(
    [Parameter(Position = 0)]
    [string]$TarFile = "",

    [string]$ConfigFile = ""
)

$ErrorActionPreference = "Stop"

$thisDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $thisDir "lib/Honeybadger.psm1") -Force -ErrorAction Stop

# Find the most recent archive. Only tar archives: a zip cannot be submitted to
# the endpoint this script targets, so offering to find one would be offering
# to submit something that is refused.
function Find-LatestArchive {
    $archives = Get-ChildItem -Filter "honeybadger-*.tar.gz" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
    if ($null -eq $archives -or @($archives).Count -eq 0) { return $null }
    return @($archives)[0].FullName
}

Write-Host "======================================"
Write-Host "Honeybadger Report Submission"
Write-Host "======================================"
Write-Host ""

# --- configuration ---------------------------------------------------------

$configPaths = if ([string]::IsNullOrWhiteSpace($ConfigFile)) {
    @(
        (Join-Path "." ".honeybadger.conf")
        (Join-Path $env:USERPROFILE ".honeybadger.conf")
        "C:\ProgramData\honeybadger.conf"
    )
} else {
    @($ConfigFile)
}

$config = Get-HbConfiguration -ConfigPath $configPaths

if (-not [string]::IsNullOrWhiteSpace($config.SourceFile)) {
    Write-Host "Loading configuration from: $($config.SourceFile)" -ForegroundColor Gray
}
if (@($config.Overridden).Count -gt 0) {
    Write-Host "Overridden by the environment: $($config.Overridden -join ', ')" -ForegroundColor Gray
}

if (-not $config.ServerEnabled) {
    Write-Host "ERROR: Server submission is disabled (SERVER_ENABLED is not 'true')" -ForegroundColor Red
    Write-Host ""
    Write-Host "To enable submission:"
    Write-Host "1. Copy .honeybadger.conf.example to .honeybadger.conf"
    Write-Host "2. Set SERVER_ENABLED=true"
    Write-Host "3. Configure SERVER_URL and SERVER_TOKEN"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($config.ServerUrl)) {
    Write-Host "ERROR: SERVER_URL not configured" -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrWhiteSpace($config.ServerToken)) {
    Write-Host "ERROR: SERVER_TOKEN not configured" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please add SERVER_TOKEN to your .honeybadger.conf file:"
    Write-Host "  SERVER_TOKEN=hb_token_your_token_here"
    exit 1
}

# --- the archive -----------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($TarFile)) {
    Write-Host "No archive specified, searching for the most recent..." -ForegroundColor Yellow
    # Tested for emptiness rather than for $null: $TarFile is declared [string],
    # so assigning $null to it stores "" and an `-eq $null` check never fires.
    # That is what turned "no archive found, run the audit" into the much less
    # helpful "Archive not found: ".
    $TarFile = Find-LatestArchive
    if ([string]::IsNullOrWhiteSpace($TarFile)) {
        Write-Host "ERROR: No honeybadger-*.tar.gz archives found" -ForegroundColor Red
        Write-Host ""
        Write-Host "Run the audit first to produce one:"
        Write-Host "  .\RUNME.cmd (or .\AUDIT.ps1)"
        exit 1
    }
    Write-Host "Found: $TarFile" -ForegroundColor Green
}

if (-not (Test-Path -LiteralPath $TarFile -PathType Leaf)) {
    Write-Host "ERROR: Archive not found: $TarFile" -ForegroundColor Red
    exit 1
}

# --- the request -----------------------------------------------------------

$hostname = $env:COMPUTERNAME
$username = $env:USERNAME
$fileSize = [math]::Round((Get-Item -LiteralPath $TarFile).Length / 1KB, 1)
$uri = Get-HbSubmissionUri $config.ServerUrl

try {
    # Throws rather than sending an empty X-Hostname: an archive the server can
    # only file under an empty name is evidence stored against nothing.
    $headers = Get-HbSubmissionHeaders -Hostname $hostname -Username $username -Token $config.ServerToken
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "  Archive:  $TarFile ($fileSize KB)"
Write-Host "  Endpoint: $uri"
Write-Host "  Hostname: $hostname"
Write-Host "  Username: $username"
Write-Host ""

if ($config.DryRun) {
    Write-Host "DRY RUN: nothing was sent." -ForegroundColor Yellow
    Write-Host "  Would POST the archive as application/x-tar with headers:" -ForegroundColor Yellow
    foreach ($key in ($headers.Keys | Sort-Object)) {
        $value = if ($key -eq "Authorization") { "Bearer <token>" } else { $headers[$key] }
        Write-Host "    ${key}: $value" -ForegroundColor Yellow
    }
    exit 0
}

# --- submission ------------------------------------------------------------

# Outcome classification is the module's, so the rules in the report-submission
# capability are decided in one place and covered by tests rather than being
# re-derived here.
$attempt = 0
$maxAttempts = [math]::Max(1, $config.RetryCount)

while ($attempt -lt $maxAttempts) {
    $attempt++
    Write-Host "Submitting (attempt $attempt/$maxAttempts)..." -ForegroundColor Green

    $statusCode = 0
    $responseBody = ""

    try {
        $response = Invoke-WebRequest `
            -Uri $uri `
            -Method Post `
            -Headers $headers `
            -InFile $TarFile `
            -ContentType "application/x-tar" `
            -TimeoutSec $config.Timeout `
            -UseBasicParsing

        $statusCode = [int]$response.StatusCode
        $responseBody = $response.Content
    } catch {
        # PowerShell throws on 4xx and 5xx instead of returning them, so the
        # status and the server's explanation have to be read off the exception.
        # A 4xx that arrives this way must still print the body - that is the
        # whole point of reporting a rejection.
        $webResponse = $null
        if ($null -ne $_.Exception.PSObject.Properties['Response']) {
            $webResponse = $_.Exception.Response
        }

        if ($null -ne $webResponse) {
            $statusCode = [int]$webResponse.StatusCode
            try {
                if ($null -ne $_.ErrorDetails -and -not [string]::IsNullOrEmpty($_.ErrorDetails.Message)) {
                    $responseBody = $_.ErrorDetails.Message
                } else {
                    $stream = $webResponse.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($stream)
                    $responseBody = $reader.ReadToEnd()
                }
            } catch {
                $responseBody = ""
            }
        } else {
            # The request did not complete at all - DNS, TLS, connection refused.
            $statusCode = 0
            $responseBody = $_.Exception.Message
        }
    }

    $outcome = Get-HbSubmissionOutcome $statusCode

    switch ($outcome) {
        "success" {
            Write-Host "✓ Submitted: $(Split-Path -Leaf $TarFile)" -ForegroundColor Green
            Write-Host "  Server response: $statusCode"
            exit 0
        }
        "partial" {
            Write-Host "✓ Partial submission: the server stored the archive but could not" -ForegroundColor Yellow
            Write-Host "  fully resolve it (HTTP 207)." -ForegroundColor Yellow
            if (-not [string]::IsNullOrWhiteSpace($responseBody)) {
                Write-Host "  Server response: $responseBody" -ForegroundColor Yellow
            }
            exit 0
        }
        "rejected" {
            Write-Host "ERROR: The server rejected the submission (HTTP $statusCode)" -ForegroundColor Red
            if (-not [string]::IsNullOrWhiteSpace($responseBody)) {
                Write-Host "  Server response: $responseBody" -ForegroundColor Red
            }
            Write-Host "  Not retrying: the server will answer the same way again." -ForegroundColor Red
            exit 1
        }
        default {
            $reason = if ($statusCode -eq 0) { "the request did not complete" } else { "HTTP $statusCode" }
            Write-Host "  Attempt $attempt failed ($reason)" -ForegroundColor Yellow
            if (-not [string]::IsNullOrWhiteSpace($responseBody)) {
                Write-Host "  $responseBody" -ForegroundColor Yellow
            }

            if ($attempt -lt $maxAttempts) {
                $delay = Get-HbRetryDelay $attempt
                Write-Host "  Retrying in $delay seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds $delay
            }
        }
    }
}

Write-Host ""
Write-Host "ERROR: Submission failed after $maxAttempts attempt(s)." -ForegroundColor Red
Write-Host "  The archive was not submitted: $TarFile" -ForegroundColor Red
exit 1
