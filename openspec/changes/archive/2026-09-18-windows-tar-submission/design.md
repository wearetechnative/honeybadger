# Design

## The constraint that shapes everything else

The Windows client is developed on machines with no Windows and no PowerShell.
That is why it has no tests, and it is the first thing to fix - otherwise this
change is a large edit to two scripts nobody can run, verified by reading.

PowerShell 7 runs on Linux. What it cannot do there is `Get-CimInstance
Win32_BIOS`, `Get-BitLockerVolume`, `Get-MpComputerStatus` or the registry. So
the split is not "Windows code and portable code" by taste; it is drawn exactly
where the Windows API surface begins:

    AUDIT.ps1                 collects from Windows, decides nothing
    lib/Honeybadger.psm1      decides everything, touches no Windows API
    submit-report.ps1         performs HTTP, decides nothing

Every function in the module takes what it needs as parameters and returns a
value. None reads the environment or the filesystem except where that is its
whole job (`Get-HbConfiguration`, `Write-HbAuditFile`), and those take the
paths to read as parameters so a test can point them anywhere.

The result is that the serial rule, the inventory document, the naming, the
config precedence and the response handling are all exercised under `pwsh` on
Linux. What remains unverified by the suite is data collection itself - which
is where it has to be, because that is the part that is genuinely Windows.

## The serial rule is copied, and that is a decision

`is_usable_serial()` in `lib/_library` is the rule the collection server
applies. `Test-HbUsableSerial` reimplements it in PowerShell: same placeholder
list, same all-zeroes rejection, same treatment of `could-not-read` and
`none-present` as non-values.

Two implementations of one rule can drift. The alternative - having the Windows
client shell out to bash - is worse on a platform that has no bash, so the
duplication is accepted and pinned instead: the Pester suite asserts the
placeholder list against the literal values, and the same real serials the bash
suite uses (`PF50L2MR`, `MP1Y69AC`, `FRANDGCPA5530200H9`) are asserted usable
in both. A change to the rule that touches one and not the other fails a test
on the side that was not changed.

`AUDIT.ps1` today stores `"Not available (VM or unknown hardware)"` in
`$script:serialNumber` and prints it in the markdown. That literal is in the
shared placeholder list, so under the shared rule it is not a serial - it is
the `none-present` case, and it is written as such.

## fastfetch on Windows produces the Linux shape

The Linux audit runs fastfetch in text mode and reshapes it with jq: the title
line `user@host` is captured, then every `Key: value` line becomes a
snake_case key. `ConvertTo-HbFastfetchJson` does the same in PowerShell,
against the same two patterns, so a Windows `fastfetch.json` and a Linux one
are read by the same `jq '.user'`.

The module parses lines it is handed. It does not run fastfetch. That keeps the
parser testable against captured output, which is the part that breaks.

`lib/fastfetch-config-windows.jsonc` is a separate file rather than a shared
one because the Linux config's `command` modules run `/etc/os-release`,
`uname`, `apt`, `dnf`, `pacman` and `nixos-rebuild`. None of them exist on
Windows. The Windows config asks fastfetch for the same *keys* through modules
that work there, so the two files differ in how they get values and agree on
what the values are called.

Where fastfetch is absent the audit installs it through winget and, failing
that, stops with a message naming the dependency. It does not fall back to
`Win32_OperatingSystem` and write a half-populated file: `fastfetch.json` with
some keys missing is indistinguishable, to a consumer, from a machine where
those values genuinely could not be read.

## The inventory document is built, not templated

`New-HbAssetInventory` takes the determinations and returns an ordered
dictionary; `ConvertTo-Json` renders it. The finding entries go through
`New-HbFinding`, which mirrors `_inventory_finding`: `N.A.` and `zie notitie`
become `null`, an empty cell becomes `null`, a canonical integer stays a
number, everything else is a string.

`ConvertTo-Json -Depth 6` is needed because the document nests four levels and
PowerShell truncates at two by default, silently, into the string
`System.Collections.Hashtable`. The depth is asserted by a test that reads a
`findings.*.value` back out.

`hardening_score` is where Windows genuinely differs. HardeningKitty reports
pass/fail counts by severity, not a 0-100 figure; Lynis reports the figure the
register's column expects. Inventing one - a pass percentage, say - would put a
number in the same column as the Linux fleet's Lynis scores that does not mean
the same thing, and the register would compare them. So `value` is `null`,
`tool` is `hardeningkitty`, and `finding` carries the counts that were actually
measured:

    "hardening_score": {
      "value": null,
      "tool": "hardeningkitty",
      "finding": "HardeningKitty: 142/193 checks passed (14 high, 23 medium, 14 low) - geen 0-100 score"
    }

This is the shape the `asset-inventory-json` capability already defines for a
deliberately undetermined value, and it is distinguishable from a key this
generation does not emit.

## tar, not zip

`tar.exe` has been in Windows since 10 build 17063 and is bsdtar. It writes the
same format the Linux client does, so no second code path exists on the server.
`Compress-Archive` is dropped rather than kept alongside: the zip cannot be
filed by the tar endpoint, and shipping both means an operator can submit the
one that does not work.

`New-HbArchiveName` and `New-HbOutputDirectoryName` produce
`honeybadger-<host>-<user>-<dd-MM-yyyy>.tar.gz` and
`output-<host>-<user>-<dd-MM-yyyy>`, the same strings `RUNME.sh:123-124` builds.
The date format is the Linux one, not the `yyyyMMdd` the Windows client used,
because `hb_parse_output_dirname` parses the former and a Windows directory
must be readable by `check-output` like any other.

## Submission

The endpoint is `SERVER_URL/submit-tar`, joined so that a configured URL with
or without a trailing slash produces one separator - the Linux client's config
ships `SERVER_URL=http://localhost:7123/` with the slash, so this is the normal
case rather than an edge one.

Outcome handling follows the capability rather than being re-decided:

| Status      | Outcome    | Retry |
|-------------|------------|-------|
| 200, 201    | success    | no    |
| 207         | partial    | no    |
| 4xx         | rejected   | no    |
| 5xx, no response | transient | yes, with backoff |

`Get-HbSubmissionOutcome` is a pure function over the status code, so every row
of that table is a test rather than an integration run. `Invoke-WebRequest`
throws on 4xx and 5xx in PowerShell instead of returning them, so the caller
reads the status off the exception's response; a 4xx that arrives as a thrown
exception must still print the server's body, which is the whole point of the
requirement.

The hostname is `$env:COMPUTERNAME`, which is always set on Windows and is
already short. There is no `hostname(1)` problem to solve here - the bug in
`2026-09-17-fix-submit-hostname-resolution` was a Unix one - but the same rule
applies at the end: a submission is not sent with an empty `X-Hostname`.

## Configuration

`Get-HbConfiguration` reads the first config file that exists, then lets the
environment override each setting, and reports which settings came from the
environment. That is the Linux precedence, from `2026-09-16-overridable-
server-configuration`, and it is what makes a one-off run against a test server
possible without editing a file.

It takes the candidate paths as a parameter so the suite can hand it a temp
directory.

## What the tests cover

Pester, in `tests/Honeybadger.Tests.ps1`, driven by `tests/run-tests.sh` so
there is one command that runs everything. When `pwsh` is not on PATH the
runner prints that it is skipping and does not fail - the bash suite is not
made unrunnable on a machine without PowerShell.

Two kinds of test. Unit tests over the module's functions, and guards over the
shipped scripts: that `neofetch` appears nowhere in `AUDIT.ps1`, that
`Compress-Archive` is gone, that `submit-report.ps1` targets `/submit-tar`.
The guards are the reason a later edit cannot quietly restore the old path, and
they are the same technique `test_hostname_resolution.sh` uses for
`hostname(1)`.
