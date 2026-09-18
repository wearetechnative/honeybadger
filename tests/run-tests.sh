#!/usr/bin/env bash
# Run the honeybadger test suite.
#
#   ./tests/run-tests.sh            run every tests/test_*.sh, then the Pester file
#   ./tests/run-tests.sh serial     run the files whose name contains "serial"
#
# Each test file runs in its own bash process, so a file that leaves globals
# behind cannot affect another.
#
# The Windows client is covered by tests/Honeybadger.Tests.ps1, which needs
# pwsh and Pester. Both are optional: without them the file is skipped with a
# message rather than failing, so this suite still runs on a machine with no
# PowerShell - which is every machine the Linux client is developed on.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
filter="${1:-}"

failed=0
total=0

echo "Running honeybadger tests"
echo

for test_file in "$TESTS_DIR"/test_*.sh; do
    [[ -f "$test_file" ]] || continue
    if [[ -n "$filter" && "$(basename "$test_file")" != *"$filter"* ]]; then
        continue
    fi
    total=$((total + 1))
    if ! bash "$test_file"; then
        failed=$((failed + 1))
    fi
    echo
done

pester_file="$TESTS_DIR/Honeybadger.Tests.ps1"
if [[ -f "$pester_file" ]] && [[ -z "$filter" || "Honeybadger.Tests.ps1" == *"$filter"* ]]; then
    if ! command -v pwsh >/dev/null 2>&1; then
        echo "  Honeybadger.Tests.ps1"
        echo "    skipped: pwsh is not installed (the Windows client's tests need it)"
        echo
    else
        total=$((total + 1))
        # shellcheck disable=SC2016  # the PowerShell block is quoted so that
        # $config and friends reach pwsh unexpanded; only $pester_file is
        # deliberately spliced in from the shell.
        if pwsh -NoProfile -Command '
            if (-not (Get-Module -ListAvailable Pester |
                      Where-Object { $_.Version.Major -ge 5 })) {
                Write-Host "  Honeybadger.Tests.ps1"
                Write-Host "    skipped: Pester 5 or later is not installed"
                Write-Host "    install it with: Install-Module Pester -Scope CurrentUser"
                exit 0
            }
            Import-Module Pester -MinimumVersion 5.0
            $config = New-PesterConfiguration
            $config.Run.Path = "'"$pester_file"'"
            $config.Run.Exit = $true
            $config.Output.Verbosity = "Normal"
            Invoke-Pester -Configuration $config
        '; then
            :
        else
            failed=$((failed + 1))
        fi
        echo
    fi
fi

if [[ $total -eq 0 ]]; then
    echo "No test files matched${filter:+ filter '$filter'}"
    exit 1
fi

if [[ $failed -gt 0 ]]; then
    echo "FAILED: $failed of $total test file(s)"
    exit 1
fi

echo "OK: $total test file(s) passed"
