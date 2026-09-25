<#
.SYNOPSIS
    Shared logic for the Honeybadger Windows client.
.DESCRIPTION
    AUDIT.ps1 and submit-report.ps1 collect from Windows and perform HTTP. This
    module decides things: what counts as a serial, what fastfetch output means,
    what the asset inventory document looks like, what a response code means.

    Nothing here touches a Windows API, reads the environment implicitly, or
    resolves a path it was not given. That is deliberate and is the whole point
    of the split: PowerShell 7 runs on Linux, Get-CimInstance does not, so this
    is the part a test can reach on the machines the client is developed on.

    The rules mirrored from lib/_library are marked as such. Two implementations
    of one rule can drift, so each is pinned by a test against the same literal
    values the bash suite uses.
#>

Set-StrictMode -Version Latest

# --- serial ----------------------------------------------------------------

# The two tokens the audit writes when there is no serial. Mirrors
# HB_SERIAL_NOT_READ / HB_SERIAL_NOT_PRESENT in lib/_library.
$script:HbSerialNotRead = 'could-not-read'
$script:HbSerialNotPresent = 'none-present'

# Mirrors HB_SERIAL_PLACEHOLDERS in lib/_library. Compared lowercased.
$script:HbSerialPlaceholders = @(
    'not available'
    'not available (vm or unknown hardware)'
    'to be filled by o.e.m.'
    'to be filled'
    'default string'
    'not specified'
    'system serial number'
    'none'
    'unknown'
)

function Get-HbSerialNotRead { $script:HbSerialNotRead }
function Get-HbSerialNotPresent { $script:HbSerialNotPresent }
function Get-HbSerialPlaceholder { $script:HbSerialPlaceholders }

<#
.SYNOPSIS
    Is this value a serial, by the rule the collection server applies?
.DESCRIPTION
    Mirrors is_usable_serial() in lib/_library: one token, no whitespace, no
    control characters, not all zeroes, not one of this tool's own no-serial
    tokens, not a known firmware placeholder.
#>
function Test-HbUsableSerial {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Value
    )

    if ([string]::IsNullOrEmpty($Value)) { return $false }

    # A serial is a single token. "Mac OS X<TAB>" fails here, as it should.
    if ($Value -match '\s') { return $false }
    if ($Value -match '[\p{Cc}]') { return $false }

    # All zeroes, at any length, is a firmware default rather than a measurement
    if ($Value -match '^0+$') { return $false }

    if ($Value -eq $script:HbSerialNotRead -or $Value -eq $script:HbSerialNotPresent) {
        return $false
    }

    if ($script:HbSerialPlaceholders -contains $Value.ToLowerInvariant()) { return $false }

    return $true
}

<#
.SYNOPSIS
    Turn a raw BIOS serial into the value, source and status the audit writes.
.PARAMETER RawSerial
    What the WMI query returned. Empty or a placeholder is a hardware that has
    none; use -QueryFailed when the query itself did not answer.
.PARAMETER QueryFailed
    The serial could not be read at all, which is a different outcome from
    hardware that has none - a VM legitimately has none.
#>
function Resolve-HbSerial {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$RawSerial,

        [switch]$QueryFailed,

        [string]$Source = 'wmi:Win32_BIOS'
    )

    if ($QueryFailed) {
        return [PSCustomObject]@{
            Value    = $script:HbSerialNotRead
            Source   = ''
            Status   = $script:HbSerialNotRead
            IsUsable = $false
        }
    }

    $trimmed = if ($null -eq $RawSerial) { '' } else { $RawSerial.Trim() }

    if (Test-HbUsableSerial $trimmed) {
        return [PSCustomObject]@{
            Value    = $trimmed
            Source   = $Source
            Status   = 'ok'
            IsUsable = $true
        }
    }

    # A placeholder is hardware reporting that it has no serial, not a failure
    # to read one. AUDIT.ps1 used to store the placeholder itself as the value.
    return [PSCustomObject]@{
        Value    = $script:HbSerialNotPresent
        Source   = $Source
        Status   = $script:HbSerialNotPresent
        IsUsable = $false
    }
}

# --- fastfetch -------------------------------------------------------------

<#
.SYNOPSIS
    Parse fastfetch's text output into the flat object RUNME.sh produces.
.DESCRIPTION
    The Linux audit pipes fastfetch through jq with two patterns: the title line
    yields user and hostname, and every remaining line containing a colon yields
    a key lowercased with spaces turned into underscores. This is the same two
    patterns, so that `jq '.user'` reads a Windows archive and a Linux one
    identically.

    It parses lines it is handed rather than running fastfetch, because the
    parser is the part that breaks and the invocation is the part that cannot be
    tested off Windows.
#>
function ConvertTo-HbFastfetchJson {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [string[]]$Lines
    )

    $result = [ordered]@{}
    if ($null -eq $Lines) { return $result }

    $nonEmpty = @($Lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($nonEmpty.Count -eq 0) { return $result }

    # Title line: user@host. jq's capture is anchored at the start and takes the
    # host as the following non-space run.
    $title = [regex]::Match($nonEmpty[0], '^(?<user>[^@]+)@(?<hostname>\S+)')
    if ($title.Success) {
        $result['user'] = $title.Groups['user'].Value
        $result['hostname'] = $title.Groups['hostname'].Value
    }

    foreach ($line in $nonEmpty[1..($nonEmpty.Count - 1)]) {
        if ($line -notmatch ':') { continue }
        $pair = [regex]::Match($line, '(?<key>[^:]+): (?<value>.*)')
        if (-not $pair.Success) { continue }

        $key = $pair.Groups['key'].Value.ToLowerInvariant() -replace ' ', '_'
        $result[$key] = $pair.Groups['value'].Value
    }

    return $result
}

# --- asset inventory -------------------------------------------------------

<#
.SYNOPSIS
    Render one value as the JSON scalar it is.
.DESCRIPTION
    Mirrors _inventory_scalar(): nothing becomes null, a canonical integer
    becomes a number, anything else stays a string. A number inside a string is
    a number the consumer has to parse, and can parse wrongly.
#>
function ConvertTo-HbInventoryScalar {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        $Raw
    )

    if ($null -eq $Raw) { return $null }
    $text = [string]$Raw
    if ($text.Length -eq 0) { return $null }

    # Canonical integers only, as jq reads "007" as 7 - a non-canonical form
    # would be silently reinterpreted rather than carried as written.
    if ($text -match '^(0|-?[1-9][0-9]*)$') { return [int]$text }

    return $text
}

<#
.SYNOPSIS
    Build one finding entry: the determined value and what it was derived from.
.DESCRIPTION
    Mirrors _inventory_finding(). "N.A." and "see note" are the spreadsheet's
    spellings of "no value here", mapped before the general rule rather than
    inside it. A null value with a finding is distinguishable from a key this
    generation does not emit, which an omitted key would not be.
#>
function New-HbFinding {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
    Justification = 'Builds and returns a value; changes no state.')]
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [AllowEmptyString()]
        $Cell,

        [Parameter(Position = 1, Mandatory)]
        [AllowEmptyString()]
        [string]$Finding,

        [Parameter(Position = 2)]
        [string]$ExtraKey,

        [Parameter(Position = 3)]
        [AllowNull()]
        $ExtraValue
    )

    $cellText = if ($null -eq $Cell) { '' } else { [string]$Cell }
    if ($cellText -eq 'N.A.' -or $cellText -eq 'see note') { $cellText = '' }

    $entry = [ordered]@{
        value   = ConvertTo-HbInventoryScalar $cellText
        finding = $Finding
    }

    if (-not [string]::IsNullOrEmpty($ExtraKey)) {
        $entry[$ExtraKey] = ConvertTo-HbInventoryScalar $ExtraValue
    }

    return $entry
}

<#
.SYNOPSIS
    Build asset-inventory.json: the machine-readable counterpart of the reports.
.DESCRIPTION
    Mirrors _write_asset_inventory_json(). Emitted from the determinations the
    compliance report renders rather than deriving them again - whether a disk
    counts as encrypted is platform-specific knowledge, and a second
    implementation of those rules would drift from the first.
#>
function New-HbAssetInventory {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
    Justification = 'Builds and returns a value; changes no state.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Hostname,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Username,
        [Parameter(Mandatory)][AllowEmptyString()][string]$ScanDate,
        [AllowNull()][AllowEmptyString()][string]$Serial,
        [AllowNull()][AllowEmptyString()][string]$Model,
        [Parameter(Mandatory)]$Findings,
        [string]$Platform = 'windows',
        [string]$HoneybadgerVersion = 'unknown',
        [string]$GeneratedAt
    )

    if ([string]::IsNullOrEmpty($GeneratedAt)) {
        $GeneratedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
    }

    # The two no-serial tokens are a status, not an identity. The server
    # resolves an asset by serial, and "none-present" is not one.
    $serialValue = $null
    if (-not [string]::IsNullOrEmpty($Serial) -and $Serial -ne 'N.A.' -and (Test-HbUsableSerial $Serial)) {
        $serialValue = $Serial
    }

    $modelValue = $null
    if (-not [string]::IsNullOrEmpty($Model) -and $Model -ne 'N.A.') {
        $modelValue = $Model
    }

    return [ordered]@{
        schema_version      = 2
        generated_at        = $GeneratedAt
        honeybadger_version = $HoneybadgerVersion
        platform            = $Platform
        scan_date           = $ScanDate
        identity            = [ordered]@{
            serial   = $serialValue
            hostname = $Hostname
            username = $Username
            model    = $modelValue
        }
        findings            = $Findings
    }
}

<#
.SYNOPSIS
    Serialise an inventory document.
.DESCRIPTION
    The document nests four levels and ConvertTo-Json truncates at two by
    default, silently, into the string "System.Collections.Hashtable". The depth
    is not incidental.
#>
function ConvertTo-HbInventoryJson {
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)]$Inventory)

    return ($Inventory | ConvertTo-Json -Depth 8)
}

<#
.SYNOPSIS
    The hardening_score entry for a tool that produces no 0-100 figure.
.DESCRIPTION
    HardeningKitty reports pass/fail counts by severity; the register's column
    expects the figure Lynis produces. Inventing one - a pass percentage, say -
    would put a number beside the Linux fleet's real scores that does not mean
    the same thing, and the register would compare them.
#>
function New-HbHardeningScoreFinding {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
    Justification = 'Builds and returns a value; changes no state.')]
    [CmdletBinding()]
    param(
        [int]$TotalChecks,
        [int]$PassedChecks,
        [int]$HighSeverity,
        [int]$MediumSeverity,
        [int]$LowSeverity,
        [switch]$NotRun
    )

    if ($NotRun -or $TotalChecks -le 0) {
        return New-HbFinding '' 'not determined - HardeningKitty was not run' 'tool' 'hardeningkitty'
    }

    $finding = "HardeningKitty: $PassedChecks/$TotalChecks checks passed " +
               "($HighSeverity high, $MediumSeverity medium, $LowSeverity low) - no 0-100 score"

    return New-HbFinding '' $finding 'tool' 'hardeningkitty'
}

# --- naming ----------------------------------------------------------------

<#
.SYNOPSIS
    The output directory name, as RUNME.sh:123 builds it.
.DESCRIPTION
    dd-MM-yyyy rather than the yyyyMMdd this client used, because
    hb_parse_output_dirname parses the former and a Windows directory has to be
    readable by check-output like any other.
#>
function Get-HbOutputDirectoryName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Hostname,
        [Parameter(Mandatory, Position = 1)][string]$Username,
        [Parameter(Position = 2)][datetime]$Date = (Get-Date)
    )

    return "output-$Hostname-$Username-$($Date.ToString('dd-MM-yyyy'))"
}

<#
.SYNOPSIS
    The archive name, as RUNME.sh:124 builds it.
#>
function Get-HbArchiveName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Hostname,
        [Parameter(Mandatory, Position = 1)][string]$Username,
        [Parameter(Position = 2)][datetime]$Date = (Get-Date)
    )

    return "honeybadger-$Hostname-$Username-$($Date.ToString('dd-MM-yyyy')).tar.gz"
}

<#
.SYNOPSIS
    The markdown report name, as hb_report_basename() builds it.
#>
function Get-HbReportName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Username,
        [Parameter(Mandatory, Position = 1)][string]$Kind,
        [Parameter(Position = 2)][datetime]$Date = (Get-Date)
    )

    return "honeybadger-$Username-$($Date.ToString('dd-MM-yyyy'))-$Kind.md"
}

# --- configuration ---------------------------------------------------------

$script:HbConfigDefaults = [ordered]@{
    SERVER_ENABLED     = 'false'
    SERVER_URL         = 'http://localhost:7123/'
    SERVER_TOKEN       = ''
    SERVER_TIMEOUT     = '30'
    SERVER_RETRY_COUNT = '3'
    DRY_RUN            = 'false'
}

<#
.SYNOPSIS
    Read the client configuration: file first, environment on top.
.DESCRIPTION
    The precedence the Linux client established in
    2026-09-16-overridable-server-configuration - anything set in the
    environment overrides the file, and the client reports which settings came
    from there. That is how one run can be pointed at a test server without
    editing a file.

    The candidate paths and the environment are parameters so the suite can hand
    it a temp directory rather than needing the real machine's config.
#>
function Get-HbConfiguration {
    [CmdletBinding()]
    param(
        [string[]]$ConfigPath,
        [hashtable]$Environment
    )

    if (-not $PSBoundParameters.ContainsKey('ConfigPath') -or $null -eq $ConfigPath) {
        $ConfigPath = @(
            (Join-Path '.' '.honeybadger.conf')
            (Join-Path $env:USERPROFILE '.honeybadger.conf')
            'C:\ProgramData\honeybadger.conf'
        )
    }

    $settings = [ordered]@{}
    foreach ($key in $script:HbConfigDefaults.Keys) {
        $settings[$key] = $script:HbConfigDefaults[$key]
    }

    $sourceFile = ''
    foreach ($candidate in $ConfigPath) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }

        $sourceFile = $candidate
        foreach ($line in (Get-Content -LiteralPath $candidate)) {
            $trimmed = $line.Trim()
            if ($trimmed.StartsWith('#') -or -not $trimmed.Contains('=')) { continue }

            $name = $trimmed.Substring(0, $trimmed.IndexOf('=')).Trim()
            $value = $trimmed.Substring($trimmed.IndexOf('=') + 1).Trim()
            if ($settings.Contains($name)) { $settings[$name] = $value }
        }
        break
    }

    # Anything in the environment wins, and is reported so an operator can see
    # why a run went somewhere other than the file says.
    $overridden = @()
    foreach ($key in @($settings.Keys)) {
        $fromEnv = $null
        if ($null -ne $Environment) {
            if ($Environment.ContainsKey($key)) { $fromEnv = [string]$Environment[$key] }
        } else {
            $item = Get-Item -LiteralPath "Env:$key" -ErrorAction SilentlyContinue
            if ($null -ne $item) { $fromEnv = $item.Value }
        }

        if (-not [string]::IsNullOrEmpty($fromEnv)) {
            $settings[$key] = $fromEnv
            $overridden += $key
        }
    }

    return [PSCustomObject]@{
        ServerEnabled = ($settings['SERVER_ENABLED'] -eq 'true')
        ServerUrl     = $settings['SERVER_URL']
        ServerToken   = $settings['SERVER_TOKEN']
        Timeout       = [int]$settings['SERVER_TIMEOUT']
        RetryCount    = [int]$settings['SERVER_RETRY_COUNT']
        DryRun        = ($settings['DRY_RUN'] -eq 'true')
        SourceFile    = $sourceFile
        Overridden    = $overridden
    }
}

# --- submission ------------------------------------------------------------

<#
.SYNOPSIS
    Join the configured server URL with the archive endpoint.
.DESCRIPTION
    The shipped config carries a trailing slash, so one separator rather than
    two is the normal case rather than an edge one.
#>
function Get-HbSubmissionUri {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)][string]$ServerUrl,
        [string]$Endpoint = 'submit-tar'
    )

    return ($ServerUrl.TrimEnd('/') + '/' + $Endpoint.TrimStart('/'))
}

<#
.SYNOPSIS
    What a response status means, per the report-submission capability.
.DESCRIPTION
    A pure function over the status code, so every row of the table in the
    capability is a test rather than an integration run. Pass 0 for a request
    that did not complete at all.
#>
function Get-HbSubmissionOutcome {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Position = 0)][int]$StatusCode)

    if ($StatusCode -eq 207) { return 'partial' }
    if ($StatusCode -eq 200 -or $StatusCode -eq 201) { return 'success' }
    if ($StatusCode -ge 400 -and $StatusCode -lt 500) { return 'rejected' }
    return 'transient'
}

<#
.SYNOPSIS
    Should this outcome be retried?
#>
function Test-HbShouldRetry {
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory, Position = 0)][string]$Outcome)

    return ($Outcome -eq 'transient')
}

<#
.SYNOPSIS
    Seconds to wait before attempt N, doubling from 2.
#>
function Get-HbRetryDelay {
    [CmdletBinding()]
    [OutputType([int])]
    param([Parameter(Mandatory, Position = 0)][int]$Attempt)

    if ($Attempt -lt 1) { $Attempt = 1 }
    return [int][math]::Pow(2, $Attempt)
}

<#
.SYNOPSIS
    The headers a submission carries.
.DESCRIPTION
    Throws when the hostname is empty rather than letting the request go out
    without one: a submission the server can only file under an empty name is
    evidence stored against nothing.
#>
function Get-HbSubmissionHeaders {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '',
        Justification = 'Returns the set of headers, not one header.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Hostname,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Username,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Token
    )

    if ([string]::IsNullOrWhiteSpace($Hostname)) {
        throw 'Could not determine this machine''s hostname; refusing to submit without one.'
    }

    return @{
        'Authorization' = "Bearer $Token"
        'X-Hostname'    = $Hostname
        'X-Username'    = $Username
    }
}

Export-ModuleMember -Function @(
    'Get-HbSerialNotRead'
    'Get-HbSerialNotPresent'
    'Get-HbSerialPlaceholder'
    'Test-HbUsableSerial'
    'Resolve-HbSerial'
    'ConvertTo-HbFastfetchJson'
    'ConvertTo-HbInventoryScalar'
    'New-HbFinding'
    'New-HbAssetInventory'
    'ConvertTo-HbInventoryJson'
    'New-HbHardeningScoreFinding'
    'Get-HbOutputDirectoryName'
    'Get-HbArchiveName'
    'Get-HbReportName'
    'Get-HbConfiguration'
    'Get-HbSubmissionUri'
    'Get-HbSubmissionOutcome'
    'Test-HbShouldRetry'
    'Get-HbRetryDelay'
    'Get-HbSubmissionHeaders'
)
