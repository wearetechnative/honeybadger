#!/usr/bin/env bash
# Run the honeybadger shell test suite.
#
#   ./tests/run-tests.sh            run every tests/test_*.sh
#   ./tests/run-tests.sh serial     run the files whose name contains "serial"
#
# Each test file runs in its own bash process, so a file that leaves globals
# behind cannot affect another.

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

if [[ $total -eq 0 ]]; then
    echo "No test files matched${filter:+ filter '$filter'}"
    exit 1
fi

if [[ $failed -gt 0 ]]; then
    echo "FAILED: $failed of $total test file(s)"
    exit 1
fi

echo "OK: $total test file(s) passed"
