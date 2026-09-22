#!/usr/bin/env bash
# The "version" command of RUNME.sh.
#
# The version reaches three consumers - the banner, lib/_library's
# asset-inventory.json and AUDIT.ps1 - all reading VERSION-honeybadger. This
# covers the one an operator types, and that it is listed rather than only
# reachable by knowing an internal function name.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
source "$TESTS_DIR/lib.sh"

test_version_reports_the_version_file() {
    local expected output
    expected="$(tr -d '[:space:]' < "$REPO_ROOT/VERSION-honeybadger")"
    output="$(cd "$REPO_ROOT" && ./RUNME.sh version 2>&1)"

    assert_contains "$output" "Honeybadger v$expected" \
        "the banner names the version in VERSION-honeybadger"
    assert_contains "$output" "a Personal Device Audit tool for ISO27001"
}

test_version_is_listed_among_the_commands() {
    local usage
    usage="$(cd "$REPO_ROOT" && ./RUNME.sh 2>&1)"
    assert_contains "$usage" "version" "the usage lists the command"
    assert_contains "$usage" "Show the Honeybadger version" "with its description"
}

# show_version still heads honeybadger-info.txt in every archive, so the
# command must not have replaced it.
test_show_version_is_still_callable() {
    local output
    output="$(cd "$REPO_ROOT" && ./RUNME.sh show_version 2>&1)"
    assert_contains "$output" "Honeybadger v" "show_version still works"
}

run_tests "$@"
