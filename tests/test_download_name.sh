#!/usr/bin/env bash
# Columns A and N of the xlsx report, from the name badgersbay gives a download.
#
# badgersbay serves an archive as <asset-ID>-<date>[-<owner>].tar.gz, which is
# the register's proof_file value. check-output run on such a download can fill
# A and N from it. Any other name must leave the report exactly as it was.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$TESTS_DIR/lib.sh"

WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
}

teardown() {
    [[ -n "$WORKDIR" ]] && rm -rf "$WORKDIR"
    WORKDIR=""
}

# Usage: expect_download <name> <asset> <proof>
expect_download() {
    hb_parse_download_name "$1"
    assert_success "'$1' is a download name" $?
    assert_equals "$2" "$HB_DOWNLOAD_ASSET" "asset ID of '$1'"
    assert_equals "$3" "$HB_DOWNLOAD_PROOF" "proof_file of '$1'"
}

# Usage: expect_not_download <name>
expect_not_download() {
    hb_parse_download_name "$1"
    assert_failure "'$1' is not a download name" $?
    assert_equals "" "$HB_DOWNLOAD_ASSET$HB_DOWNLOAD_PROOF" "nothing set for '$1'"
}

# ------------------------------------------------------- recognising the name

test_a_download_with_an_owner() {
    expect_download "TARI-00023-2026-09-17-wouter.toorren.tar.gz" \
        "TARI-00023" "TARI-00023-2026-09-17-wouter.toorren"
}

test_a_download_without_an_owner() {
    # badgersbay omits the slug when the register names no owner.
    expect_download "TARI-00042-2026-09-17.tar" "TARI-00042" "TARI-00042-2026-09-17"
}

test_names_that_are_not_downloads() {
    expect_not_download "honeybadger-lobos-wtoorren-25-09-2026.tar.gz"   # a local audit
    expect_not_download "PF3NCBYR-2026-09-17.tar.gz"                     # an unmatched submission
    expect_not_download "TARI-00023-2026-09-17-wouter.toorren (1).tar.gz" # a browser duplicate
    expect_not_download "TARI-00023-2026-02-30.tar.gz"                   # not a calendar date
    expect_not_download "TARI-0023-2026-09-17.tar.gz"                    # would give column M a wrong date
    expect_not_download "TARI-00023-2026-09-17-wouter.toorren"           # no archive extension
}

# ------------------------------------------------------- the report

# A minimal output directory the xlsx report can render from.
# Usage: output_fixture <dir>
output_fixture() {
    mkdir -p "$1"
    echo '{"hostname": "host", "hardening_index": "70", "firewall_active": "1",
           "report_datetime_start": "2026-09-17 10:00:00",
           "package_audit_tool_found": "1", "vulnerable_packages_found": "0"}' > "$1/lynis-report.json"
    echo "nvme0n1p2 crypto_LUKS 2" > "$1/blockdevices.txt"
}

# Usage: render_xlsx <dir> [archive name]   -> prints the report
render_xlsx() {
    rm -f "$WORKDIR"/honeybadger-*-xlsx.md
    (cd "$WORKDIR" && generate_xlsx_asset_row_report "$1" "${2:-}" >/dev/null 2>&1)
    cat "$WORKDIR"/honeybadger-*-xlsx.md
}

test_a_download_fills_asset_and_proof_file() {
    setup
    local dir="$WORKDIR/output-host-user-17-09-2026" report by_hand
    output_fixture "$dir"
    report=$(render_xlsx "$dir" "TARI-00023-2026-09-17-wouter.toorren.tar.gz")

    assert_contains "$report" "| A   | Asset " "A is in the determined table"
    assert_contains "$report" "| TARI-00023 " "with the asset ID"
    assert_contains "$report" "| TARI-00023-2026-09-17-wouter.toorren " "N is the archive name"
    assert_contains "$report" "from the archive name (TARI-00023-2026-09-17-wouter.toorren.tar.gz)" \
        "and says where it came from"

    by_hand=$(sed -n '/^## Maintained by hand/,/^---/p' <<< "$report")
    [[ "$by_hand" != *"| A "* && "$by_hand" != *"| N "* ]]
    assert_success "A and N are no longer maintained by hand" $?
    assert_contains "$by_hand" "| C   | Owner " "C still is"
    assert_contains "$by_hand" "| O   | Remarks " "and O"
    teardown
}

test_any_other_name_leaves_the_report_unchanged() {
    setup
    local dir="$WORKDIR/output-host-user-17-09-2026" without with_local with_unmatched
    output_fixture "$dir"
    without=$(render_xlsx "$dir")
    with_local=$(render_xlsx "$dir" "honeybadger-host-user-17-09-2026.tar.gz")
    with_unmatched=$(render_xlsx "$dir" "PF3NCBYR-2026-09-17.tar.gz")

    assert_equals "$without" "$with_local" "a local audit's archive"
    assert_equals "$without" "$with_unmatched" "an unmatched submission's download"
    assert_contains "$without" "| A   | Asset      | asset ID from the register" "A is left to the operator"
    teardown
}

run_tests "$@"
