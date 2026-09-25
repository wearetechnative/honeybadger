# Pester tests for the Honeybadger Windows client.
#
# These cover lib/Honeybadger.psm1 - the part of the client that decides things
# rather than the part that reads Windows. That split is what makes them
# runnable here at all: PowerShell 7 runs on Linux, Get-CimInstance does not.
#
# Run with tests/run-tests.sh, or directly:
#   pwsh -NoProfile -Command 'Invoke-Pester tests/Honeybadger.Tests.ps1'

BeforeAll {
    $script:RepoRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $script:RepoRoot "lib/Honeybadger.psm1") -Force
}

Describe "Test-HbUsableSerial" {
    # The rule lives in two implementations - is_usable_serial() in
    # lib/_library and this one - because there is no bash on Windows to shell
    # out to. The duplication is pinned here against the same literal values
    # the bash suite uses, so a change to one side that is not made to the
    # other fails on the side that was not changed.

    It "accepts <Serial>, a real serial found on the fleet" -ForEach @(
        @{ Serial = "PF50L2MR" }
        @{ Serial = "MP1Y69AC" }
        @{ Serial = "FRANDGCPA5530200H9" }
        @{ Serial = "YD063JGA" }
    ) {
        Test-HbUsableSerial $Serial | Should -BeTrue
    }

    It "rejects the empty string" {
        Test-HbUsableSerial "" | Should -BeFalse
    }

    It "rejects a value containing whitespace" {
        # "Mac OS X<TAB>" is what the macOS client used to write by parsing a
        # human-readable report. A serial is one token.
        Test-HbUsableSerial "Mac OS X`t" | Should -BeFalse
        Test-HbUsableSerial "PF50 L2MR" | Should -BeFalse
    }

    It "rejects all zeroes at any length" {
        Test-HbUsableSerial "0" | Should -BeFalse
        Test-HbUsableSerial "0000000000" | Should -BeFalse
    }

    It "accepts a value that merely starts with zero" {
        Test-HbUsableSerial "0ABC123" | Should -BeTrue
    }

    It "rejects the placeholder <Placeholder>" -ForEach @(
        @{ Placeholder = "Not available" }
        @{ Placeholder = "To Be Filled By O.E.M." }
        @{ Placeholder = "Default string" }
        @{ Placeholder = "Not Specified" }
        @{ Placeholder = "System Serial Number" }
        @{ Placeholder = "None" }
        @{ Placeholder = "Unknown" }
    ) {
        Test-HbUsableSerial $Placeholder | Should -BeFalse
    }

    It "rejects a placeholder regardless of case" {
        Test-HbUsableSerial "not available" | Should -BeFalse
        Test-HbUsableSerial "DEFAULT STRING" | Should -BeFalse
    }

    It "rejects the literal AUDIT.ps1 used to store as a measured serial" {
        # This is the defect: the string was written into the compliance report
        # where a serial belongs. It is a placeholder, not a value.
        Test-HbUsableSerial "Not available (VM or unknown hardware)" | Should -BeFalse
    }

    It "rejects the two tokens the audit itself writes when there is none" {
        Test-HbUsableSerial "could-not-read" | Should -BeFalse
        Test-HbUsableSerial "none-present" | Should -BeFalse
    }

    It "carries the same placeholder list as lib/_library" {
        # Read the bash array and compare, so the two cannot drift silently.
        $libraryPath = Join-Path $script:RepoRoot "lib/_library"
        $content = Get-Content -Raw $libraryPath
        $match = [regex]::Match($content, '(?s)HB_SERIAL_PLACEHOLDERS=\((?<body>.*?)\n\)')
        $match.Success | Should -BeTrue -Because "lib/_library should declare HB_SERIAL_PLACEHOLDERS"

        $bashList = [regex]::Matches($match.Groups['body'].Value, '"(?<value>[^"]+)"') |
            ForEach-Object { $_.Groups['value'].Value } | Sort-Object

        $psList = @(Get-HbSerialPlaceholder) | Sort-Object

        ($psList -join "|") | Should -Be ($bashList -join "|")
    }
}

Describe "Resolve-HbSerial" {
    It "reports a usable serial with its source" {
        $result = Resolve-HbSerial "PF50L2MR"
        $result.Value | Should -Be "PF50L2MR"
        $result.Status | Should -Be "ok"
        $result.Source | Should -Be "wmi:Win32_BIOS"
        $result.IsUsable | Should -BeTrue
    }

    It "trims surrounding whitespace before judging the value" {
        # WMI commonly returns a padded string.
        $result = Resolve-HbSerial "  PF50L2MR  "
        $result.Value | Should -Be "PF50L2MR"
        $result.IsUsable | Should -BeTrue
    }

    It "writes none-present for a firmware placeholder" {
        # What a virtual machine legitimately reports.
        $result = Resolve-HbSerial "To Be Filled By O.E.M."
        $result.Value | Should -Be "none-present"
        $result.Status | Should -Be "none-present"
        $result.IsUsable | Should -BeFalse
    }

    It "writes none-present for an empty value" {
        (Resolve-HbSerial "").Value | Should -Be "none-present"
    }

    It "writes could-not-read when the query failed" {
        # A different outcome from hardware that has no serial, and the operator
        # needs to be able to tell them apart.
        $result = Resolve-HbSerial -QueryFailed
        $result.Value | Should -Be "could-not-read"
        $result.Status | Should -Be "could-not-read"
        $result.IsUsable | Should -BeFalse
    }

    It "never returns the placeholder itself as the value" {
        $result = Resolve-HbSerial "Not available (VM or unknown hardware)"
        $result.Value | Should -Not -Match "Not available"
    }
}

Describe "ConvertTo-HbFastfetchJson" {
    BeforeAll {
        $script:SampleOutput = @(
            "elma@LAPTOP-AC06CMEP"
            "--------------------"
            "OS: Windows 11 Pro 10.0.26100 x86_64"
            "Host: 21K9CTO1WW (ThinkPad P16s Gen 2)"
            "Hostname: LAPTOP-AC06CMEP"
            "Kernel: 10.0.26100.1"
            "Uptime: 4 days, 1 hour, 19 mins"
            "CPU: AMD Ryzen 7 PRO 7840U (16) @ 5.13 GHz"
            "Local IP: 10.8.0.6/24"
            "Date: 2026-09-15 10:25"
        )
        $script:Parsed = ConvertTo-HbFastfetchJson $script:SampleOutput
    }

    It "takes the user and hostname from the title line" {
        # hb_audit_username() reads .user, so this is the field that decides
        # which person a Windows submission is attributed to.
        $script:Parsed["user"] | Should -Be "elma"
        $script:Parsed["hostname"] | Should -Be "LAPTOP-AC06CMEP"
    }

    It "lowercases keys and turns spaces into underscores" {
        # The same transformation the jq expression in RUNME.sh applies, so one
        # consumer reads a Windows archive and a Linux one.
        $script:Parsed.Contains("local_ip") | Should -BeTrue
        $script:Parsed["local_ip"] | Should -Be "10.8.0.6/24"
    }

    It "keeps a value containing a colon intact" {
        $script:Parsed["date"] | Should -Be "2026-09-15 10:25"
        $script:Parsed["cpu"] | Should -Be "AMD Ryzen 7 PRO 7840U (16) @ 5.13 GHz"
    }

    It "skips the separator line" {
        $script:Parsed.Contains("--------------------") | Should -BeFalse
    }

    It "produces the keys the asset inventory reads" {
        foreach ($key in @("os", "host", "kernel")) {
            $script:Parsed.Contains($key) | Should -BeTrue -Because "$key feeds asset-inventory.json"
        }
    }

    It "returns an empty object rather than failing on no output" {
        (ConvertTo-HbFastfetchJson @()).Count | Should -Be 0
        (ConvertTo-HbFastfetchJson $null).Count | Should -Be 0
    }

    It "ignores blank lines" {
        $parsed = ConvertTo-HbFastfetchJson @("a@b", "", "OS: Windows", "   ")
        $parsed["os"] | Should -Be "Windows"
    }
}

Describe "ConvertTo-HbInventoryScalar" {
    It "renders nothing as null" {
        ConvertTo-HbInventoryScalar "" | Should -BeNullOrEmpty
        ConvertTo-HbInventoryScalar $null | Should -BeNullOrEmpty
    }

    It "renders a canonical integer as a number" {
        # A number inside a string is a number the consumer has to parse, and
        # can parse wrongly.
        ConvertTo-HbInventoryScalar "71" | Should -BeOfType [int]
        ConvertTo-HbInventoryScalar "0" | Should -BeOfType [int]
        ConvertTo-HbInventoryScalar "-3" | Should -BeOfType [int]
    }

    It "keeps a non-canonical integer as a string" {
        # jq reads "007" as 7, so carrying it as written is the only way not to
        # reinterpret it silently.
        ConvertTo-HbInventoryScalar "007" | Should -BeOfType [string]
    }

    It "renders anything else as a string" {
        ConvertTo-HbInventoryScalar "Yes" | Should -BeOfType [string]
    }
}

Describe "New-HbFinding" {
    It "carries both the value and what it was derived from" {
        $finding = New-HbFinding "Yes" "Yes (BitLocker)"
        $finding["value"] | Should -Be "Yes"
        $finding["finding"] | Should -Be "Yes (BitLocker)"
    }

    It "maps the spreadsheet's spellings of no-value to null" {
        (New-HbFinding "N.A." "not determined")["value"] | Should -BeNullOrEmpty
        (New-HbFinding "see note" "see note")["value"] | Should -BeNullOrEmpty
    }

    It "keeps the finding text when the value is null" {
        # "not determined, and here is why" has to stay distinguishable from a
        # key this generation does not emit at all.
        $finding = New-HbFinding "" "not determined - no tool present"
        $finding["value"] | Should -BeNullOrEmpty
        $finding["finding"] | Should -Be "not determined - no tool present"
    }

    It "carries an extra field beside the cell value" {
        $finding = New-HbFinding "" "one vulnerable package" "count" 1
        $finding["value"] | Should -BeNullOrEmpty
        $finding["count"] | Should -Be 1
        $finding["count"] | Should -BeOfType [int]
    }

    It "distinguishes a measured zero from nothing looked" {
        (New-HbFinding "" "none found" "count" 0)["count"] | Should -Be 0
        (New-HbFinding "" "no tool present" "count" $null)["count"] | Should -BeNullOrEmpty
    }
}

Describe "New-HbHardeningScoreFinding" {
    It "declines to assert a score and names the tool" {
        # HardeningKitty reports counts by severity, not a figure out of 100.
        # Inventing one would put a number beside the Linux fleet's Lynis scores
        # that does not mean the same thing.
        $finding = New-HbHardeningScoreFinding -TotalChecks 193 -PassedChecks 142 `
            -HighSeverity 14 -MediumSeverity 23 -LowSeverity 14
        $finding["value"] | Should -BeNullOrEmpty
        $finding["tool"] | Should -Be "hardeningkitty"
    }

    It "reports what was actually measured" {
        $finding = New-HbHardeningScoreFinding -TotalChecks 193 -PassedChecks 142 `
            -HighSeverity 14 -MediumSeverity 23 -LowSeverity 14
        $finding["finding"] | Should -Match "142/193"
        $finding["finding"] | Should -Match "14 high"
        $finding["finding"] | Should -Match "23 medium"
    }

    It "says so when HardeningKitty did not run" {
        $finding = New-HbHardeningScoreFinding -NotRun
        $finding["value"] | Should -BeNullOrEmpty
        $finding["tool"] | Should -Be "hardeningkitty"
        $finding["finding"] | Should -Match "was not run"
    }

    It "treats zero checks as not run rather than as a perfect score" {
        (New-HbHardeningScoreFinding -TotalChecks 0 -PassedChecks 0)["finding"] |
            Should -Match "was not run"
    }
}

Describe "New-HbAssetInventory" {
    BeforeAll {
        $script:Findings = [ordered]@{
            os = New-HbFinding "Windows 11 Pro" "Windows 11 Pro 10.0.26100"
            disk_encryption = New-HbFinding "Yes" "Yes (BitLocker)"
            hardening_score = New-HbHardeningScoreFinding -TotalChecks 193 -PassedChecks 142 `
                -HighSeverity 14 -MediumSeverity 23 -LowSeverity 14
        }
        $script:Inventory = New-HbAssetInventory `
            -Hostname "LAPTOP-AC06CMEP" -Username "elma" `
            -ScanDate "2026-09-15 10:00:00" -Serial "YD063JGA" `
            -Model "21K9CTO1WW" -Findings $script:Findings `
            -HoneybadgerVersion "0.4.1" -GeneratedAt "2026-09-15T10:00:00+02:00"
        $script:Json = ConvertTo-HbInventoryJson $script:Inventory
        $script:RoundTripped = $script:Json | ConvertFrom-Json
    }

    It "carries the schema generation as an integer" {
        # An integral JSON number, not a string. ConvertFrom-Json widens it to
        # [long], so the assertion is about the JSON type rather than the .NET one.
        $script:RoundTripped.schema_version | Should -Be 2
        $script:Json | Should -Match '"schema_version":\s*2\s*,'
        $script:Json | Should -Not -Match '"schema_version":\s*"'
    }

    It "identifies the platform as windows" {
        $script:RoundTripped.platform | Should -Be "windows"
    }

    It "carries the hardware serial as the stable identity" {
        $script:RoundTripped.identity.serial | Should -Be "YD063JGA"
    }

    It "populates the remaining identity fields when there is no serial" {
        $inventory = New-HbAssetInventory -Hostname "LAPTOP-AC06CMEP" -Username "elma" `
            -ScanDate "2026-09-15" -Serial "none-present" -Model "" -Findings $script:Findings
        $result = ConvertTo-HbInventoryJson $inventory | ConvertFrom-Json
        $result.identity.serial | Should -BeNullOrEmpty
        $result.identity.hostname | Should -Be "LAPTOP-AC06CMEP"
        $result.identity.username | Should -Be "elma"
    }

    It "never records a no-serial token as the identity" {
        # none-present is a status. The server resolves an asset by serial, and
        # that is not one.
        foreach ($token in @("none-present", "could-not-read")) {
            $inventory = New-HbAssetInventory -Hostname "h" -Username "u" `
                -ScanDate "d" -Serial $token -Findings $script:Findings
            (ConvertTo-HbInventoryJson $inventory | ConvertFrom-Json).identity.serial |
                Should -BeNullOrEmpty
        }
    }

    It "survives serialisation without collapsing a nested branch" {
        # ConvertTo-Json truncates at depth 2 by default, silently, into the
        # string "System.Collections.Hashtable".
        $script:Json | Should -Not -Match "System.Collections"
        $script:RoundTripped.findings.disk_encryption.value | Should -Be "Yes"
        $script:RoundTripped.findings.hardening_score.tool | Should -Be "hardeningkitty"
    }

    It "is valid JSON when findings could not be determined" {
        $partial = [ordered]@{
            os = New-HbFinding "" "not determined"
            hardening_score = New-HbHardeningScoreFinding -NotRun
        }
        $inventory = New-HbAssetInventory -Hostname "h" -Username "u" -ScanDate "d" `
            -Serial "" -Model "" -Findings $partial
        { ConvertTo-HbInventoryJson $inventory | ConvertFrom-Json } | Should -Not -Throw
    }

    It "produces the same top-level keys as the Linux client" {
        $expected = @("schema_version", "generated_at", "honeybadger_version",
                      "platform", "scan_date", "identity", "findings")
        $actual = $script:RoundTripped.PSObject.Properties.Name
        foreach ($key in $expected) {
            $actual | Should -Contain $key
        }
    }
}

Describe "Output and archive naming" {
    BeforeAll {
        $script:Date = [datetime]"2026-09-15"
    }

    It "names the output directory the way RUNME.sh does" {
        Get-HbOutputDirectoryName "LAPTOP-AC06CMEP" "elma" $script:Date |
            Should -Be "output-LAPTOP-AC06CMEP-elma-15-09-2026"
    }

    It "names the archive the way RUNME.sh does" {
        Get-HbArchiveName "LAPTOP-AC06CMEP" "elma" $script:Date |
            Should -Be "honeybadger-LAPTOP-AC06CMEP-elma-15-09-2026.tar.gz"
    }

    It "uses dd-MM-yyyy, which is what the shared parser reads" {
        # hb_parse_output_dirname parses this form. The Windows client used
        # yyyyMMdd, which that parser does not read.
        Get-HbOutputDirectoryName "h" "u" $script:Date | Should -Match "15-09-2026$"
        Get-HbOutputDirectoryName "h" "u" $script:Date | Should -Not -Match "20260915"
    }

    It "names the markdown reports the way hb_report_basename does" {
        Get-HbReportName "elma" "compliance" $script:Date |
            Should -Be "honeybadger-elma-15-09-2026-compliance.md"
        Get-HbReportName "elma" "actions" $script:Date |
            Should -Be "honeybadger-elma-15-09-2026-actions.md"
    }

    It "produces an archive name whose directory is the output directory" {
        $dir = Get-HbOutputDirectoryName "host" "user" $script:Date
        $archive = Get-HbArchiveName "host" "user" $script:Date
        $archive | Should -Be ("honeybadger-" + $dir.Substring("output-".Length) + ".tar.gz")
    }
}

Describe "Get-HbConfiguration" {
    BeforeAll {
        $script:ConfigDir = Join-Path ([System.IO.Path]::GetTempPath()) ("hb-config-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:ConfigDir -Force | Out-Null
        $script:ConfigFile = Join-Path $script:ConfigDir ".honeybadger.conf"
        @(
            "# Honeybadger configuration"
            "SERVER_ENABLED=true"
            "SERVER_URL=https://badgersbay.example/"
            "SERVER_TOKEN=hb_token_from_file"
            "SERVER_RETRY_COUNT=5"
            "DRY_RUN=false"
        ) | Set-Content -Path $script:ConfigFile
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:ConfigDir -ErrorAction SilentlyContinue
    }

    It "reads the settings from the file" {
        $config = Get-HbConfiguration -ConfigPath @($script:ConfigFile) -Environment @{}
        $config.ServerEnabled | Should -BeTrue
        $config.ServerUrl | Should -Be "https://badgersbay.example/"
        $config.ServerToken | Should -Be "hb_token_from_file"
        $config.RetryCount | Should -Be 5
        $config.DryRun | Should -BeFalse
    }

    It "lets the environment override the file" {
        # This is how one run is pointed at a test server without editing a file.
        $config = Get-HbConfiguration -ConfigPath @($script:ConfigFile) `
            -Environment @{ SERVER_URL = "http://localhost:7123/"; DRY_RUN = "true" }
        $config.ServerUrl | Should -Be "http://localhost:7123/"
        $config.DryRun | Should -BeTrue
        $config.ServerToken | Should -Be "hb_token_from_file"
    }

    It "reports which settings came from the environment" {
        $config = Get-HbConfiguration -ConfigPath @($script:ConfigFile) `
            -Environment @{ SERVER_URL = "http://localhost:7123/" }
        $config.Overridden | Should -Contain "SERVER_URL"
        $config.Overridden | Should -Not -Contain "SERVER_TOKEN"
    }

    It "ignores comments and blank lines" {
        $config = Get-HbConfiguration -ConfigPath @($script:ConfigFile) -Environment @{}
        $config.ServerUrl | Should -Not -Match "^#"
    }

    It "falls back to defaults when no config file exists" {
        $config = Get-HbConfiguration -ConfigPath @("/nonexistent/.honeybadger.conf") -Environment @{}
        $config.ServerEnabled | Should -BeFalse
        $config.SourceFile | Should -BeNullOrEmpty
        $config.RetryCount | Should -Be 3
    }

    It "treats submission as disabled unless SERVER_ENABLED is exactly true" {
        $config = Get-HbConfiguration -ConfigPath @("/nonexistent") -Environment @{ SERVER_ENABLED = "yes" }
        $config.ServerEnabled | Should -BeFalse
    }

    It "uses the first config file that exists" {
        $config = Get-HbConfiguration `
            -ConfigPath @("/nonexistent/a.conf", $script:ConfigFile) -Environment @{}
        $config.SourceFile | Should -Be $script:ConfigFile
    }
}

Describe "Get-HbSubmissionUri" {
    It "targets the archive endpoint" {
        # Not SERVER_URL itself: that endpoint has no concept of a hardware
        # serial, so submissions to it cannot be attributed to an asset.
        Get-HbSubmissionUri "http://localhost:7123/" | Should -Be "http://localhost:7123/submit-tar"
    }

    It "produces one separator whether or not the URL has a trailing slash" {
        Get-HbSubmissionUri "http://localhost:7123" | Should -Be "http://localhost:7123/submit-tar"
        Get-HbSubmissionUri "http://localhost:7123///" | Should -Be "http://localhost:7123/submit-tar"
    }

    It "keeps a path prefix in the configured URL" {
        Get-HbSubmissionUri "https://example.test/honeybadger/" |
            Should -Be "https://example.test/honeybadger/submit-tar"
    }
}

Describe "Get-HbSubmissionOutcome" {
    It "treats <Status> as <Expected>" -ForEach @(
        @{ Status = 200; Expected = "success" }
        @{ Status = 201; Expected = "success" }
        @{ Status = 207; Expected = "partial" }
        @{ Status = 400; Expected = "rejected" }
        @{ Status = 401; Expected = "rejected" }
        @{ Status = 404; Expected = "rejected" }
        @{ Status = 413; Expected = "rejected" }
        @{ Status = 500; Expected = "transient" }
        @{ Status = 502; Expected = "transient" }
        @{ Status = 503; Expected = "transient" }
        @{ Status = 0;   Expected = "transient" }
    ) {
        Get-HbSubmissionOutcome $Status | Should -Be $Expected
    }

    It "retries only what is worth retrying" {
        Test-HbShouldRetry "transient" | Should -BeTrue
        Test-HbShouldRetry "rejected" | Should -BeFalse
        Test-HbShouldRetry "partial" | Should -BeFalse
        Test-HbShouldRetry "success" | Should -BeFalse
    }

    It "does not retry a 207, which is a stored submission" {
        Test-HbShouldRetry (Get-HbSubmissionOutcome 207) | Should -BeFalse
    }

    It "backs off exponentially" {
        Get-HbRetryDelay 1 | Should -Be 2
        Get-HbRetryDelay 2 | Should -Be 4
        Get-HbRetryDelay 3 | Should -Be 8
    }
}

Describe "Get-HbSubmissionHeaders" {
    It "carries the token and the identification headers" {
        $headers = Get-HbSubmissionHeaders -Hostname "LAPTOP-AC06CMEP" -Username "elma" -Token "hb_token_x"
        $headers["Authorization"] | Should -Be "Bearer hb_token_x"
        $headers["X-Hostname"] | Should -Be "LAPTOP-AC06CMEP"
        $headers["X-Username"] | Should -Be "elma"
    }

    It "names no report type" {
        # The server derives them from the file names inside the archive.
        $headers = Get-HbSubmissionHeaders -Hostname "h" -Username "u" -Token "t"
        $headers.Keys | Should -Not -Contain "X-Report-Type"
    }

    It "refuses to build a request with no hostname" {
        # A submission the server can only file under an empty name is evidence
        # stored against nothing - and curl and Invoke-WebRequest both drop an
        # empty header rather than sending it, so the failure would be silent.
        { Get-HbSubmissionHeaders -Hostname "" -Username "u" -Token "t" } | Should -Throw
        { Get-HbSubmissionHeaders -Hostname "   " -Username "u" -Token "t" } | Should -Throw
    }
}

Describe "The shipped scripts" {
    # Guards. The same technique test_hostname_resolution.sh uses for
    # hostname(1): a later edit that restores the old path fails the suite
    # rather than being noticed in a register weeks later.

    BeforeAll {
        $script:Audit = Get-Content -Raw (Join-Path $script:RepoRoot "AUDIT.ps1")
        $script:Submit = Get-Content -Raw (Join-Path $script:RepoRoot "submit-report.ps1")

        # Full-line comments are stripped, so prose recording what the old code
        # did is not reported as the old code.
        $script:AuditCode = ((Get-Content (Join-Path $script:RepoRoot "AUDIT.ps1")) |
            Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
        $script:SubmitCode = ((Get-Content (Join-Path $script:RepoRoot "submit-report.ps1")) |
            Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
    }

    It "does not install or invoke neofetch" {
        $script:AuditCode | Should -Not -Match "neofetch"
    }

    It "does not write a legacy system information file" {
        $script:AuditCode | Should -Not -Match "neofetch\.txt"
        $script:AuditCode | Should -Not -Match "fastfetch\.txt"
    }

    It "writes fastfetch.json" {
        $script:AuditCode | Should -Match "fastfetch\.json"
    }

    It "writes the hardware serial to a file" {
        $script:AuditCode | Should -Match "hardware-serial\.txt"
    }

    It "writes asset-inventory.json" {
        $script:AuditCode | Should -Match "asset-inventory\.json"
    }

    It "does not produce a zip archive" {
        # A zip cannot be submitted to the archive endpoint, so shipping one
        # means an operator can submit the bundle that does not work.
        $script:AuditCode | Should -Not -Match "Compress-Archive"
        $script:AuditCode | Should -Not -Match "\.zip"
    }

    It "does not decide serial usability with a regex of its own" {
        # The rule belongs in one place. This is the pattern that used to live
        # in AUDIT.ps1 beside the WMI query.
        $script:AuditCode | Should -Not -Match "To Be Filled\|"
        $script:AuditCode | Should -Not -Match "Not available \(VM or unknown hardware\)"
    }

    It "submits to the archive endpoint" {
        $script:SubmitCode | Should -Match "submit-tar"
    }

    It "does not submit a zip" {
        $script:SubmitCode | Should -Not -Match "application/zip"
        $script:SubmitCode | Should -Not -Match "honeybadger-\*\.zip"
    }

    It "sends the archive as a tar" {
        $script:SubmitCode | Should -Match "application/x-tar"
    }

    It "names no report type in the request" {
        $script:SubmitCode | Should -Not -Match "X-Report-Type"
    }

    It "tests the found archive for emptiness, not for null" {
        # $TarFile is declared [string], so assigning $null to it stores "" and
        # an -eq $null check never fires. That turned "no archive found, run the
        # audit" into "Archive not found: " with nothing after the colon.
        $script:SubmitCode | Should -Not -Match '\$null -eq \$TarFile'
        $script:SubmitCode | Should -Match 'IsNullOrWhiteSpace\(\$TarFile\)'
    }

    It "prints the configured URL rather than interpolating a property off a hashtable" {
        # "$config.SERVER_URL" renders as the hashtable followed by a literal
        # .SERVER_URL, so the operator was never shown where the report went.
        $script:SubmitCode | Should -Not -Match '\$config\.SERVER_URL"'
    }

    It "both scripts use the shared module" {
        $script:AuditCode | Should -Match "Honeybadger\.psm1"
        $script:SubmitCode | Should -Match "Honeybadger\.psm1"
    }
}
