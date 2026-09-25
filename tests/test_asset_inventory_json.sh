#!/usr/bin/env bash
# asset-inventory.json: the machine-readable counterpart of the asset inventory.
#
# It is emitted from the same determinations the xlsx report renders, so the two
# cannot disagree. These tests pin the shape a consumer relies on - in
# particular that a value the audit could not or would not determine is null
# with the finding intact, rather than an absent key.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$TESTS_DIR/lib.sh"

INVENTORY_WORKDIR=""

setup_inventory_env() {
    INVENTORY_WORKDIR="$(mktemp -d)"
}

teardown_inventory_env() {
    [[ -n "$INVENTORY_WORKDIR" ]] && rm -rf "$INVENTORY_WORKDIR"
    INVENTORY_WORKDIR=""
}

# ------------------------------------------------------- finding rendering

test_a_determined_string_keeps_its_value_and_finding() {
    local out
    out=$(_inventory_finding disk_encryption "Yes" "Yes (LUKS)")

    assert_equals "Yes" "$(jq -r .value <<< "$out")" "the cell value is the value"
    assert_equals "Yes (LUKS)" "$(jq -r .finding <<< "$out")" "the finding travels with it"
}

test_a_numeric_value_is_a_number_not_a_string() {
    # A consumer comparing a hardening score against a threshold should not have
    # to parse it back out of a string.
    local out
    out=$(_inventory_finding hardening_score "72" "72/100")

    assert_equals "number" "$(jq -r '.value | type' <<< "$out")" "the score is a number"
    assert_equals "72" "$(jq -r .value <<< "$out")" "and it is the right one"
}

test_an_undetermined_value_is_null_with_the_finding_intact() {
    # "N.A." is what the xlsx report renders when a source was unavailable.
    local out
    out=$(_inventory_finding firewall "N.A." "firewall status could not be determined")

    assert_equals "null" "$(jq -r '.value | tostring' <<< "$out")" "the value is null"
    assert_contains "$(jq -r .finding <<< "$out")" "could not be determined" "the reason survives"
}

test_a_declined_value_is_null_with_the_finding_intact() {
    # Vulnerable packages: the audit deliberately asserts no value, because the
    # spreadsheet contradicts itself about which one means compliant. That
    # refusal is information and has to survive serialisation.
    local out
    out=$(_inventory_finding vulnerable_packages "" "not determined - no package audit tool present")

    assert_equals "null" "$(jq -r '.value | tostring' <<< "$out")" "the value is null"
    assert_contains "$(jq -r .finding <<< "$out")" "no package audit tool" "the reason says why"
}

test_null_is_distinguishable_from_an_absent_key() {
    # A consumer must be able to tell "not determined, and here is why" from
    # "this generation of the client does not report it at all".
    local out
    out=$(_inventory_finding firewall "N.A." "unavailable")

    assert_equals "true" "$(jq 'has("value")' <<< "$out")" "the key is present"
    assert_equals "null" "$(jq -r '.value | tostring' <<< "$out")" "and its value is null"
}

test_the_hardening_score_names_its_tool() {
    # Windows arrives with HardeningKitty where Linux has Lynis, so a bare
    # number is not enough to compare against anything.
    local out
    out=$(_inventory_finding hardening_score "72" "72/100" tool lynis)

    assert_equals "lynis" "$(jq -r .tool <<< "$out")" "the tool is named"
}

test_a_value_containing_quotes_stays_valid_json() {
    local out
    out=$(_inventory_finding model 'LENOVO "21K9" Gen 2' 'from fastfetch')

    assert_success "rendering a value with quotes" $?
    assert_equals 'LENOVO "21K9" Gen 2' "$(jq -r .value <<< "$out")" "the quotes survive"
}

# -------------------------------------------------------- scalar rendering

test_scalar_renders_nothing_as_null() {
    assert_equals "null" "$(_inventory_scalar "")" "an empty value is null"
}

test_scalar_renders_whole_numbers_as_numbers() {
    assert_equals "0" "$(_inventory_scalar "0")" "zero"
    assert_equals "1" "$(_inventory_scalar "1")" "one"
    assert_equals "-3" "$(_inventory_scalar "-3")" "a negative"
}

test_scalar_renders_anything_else_as_a_string() {
    assert_equals '"lynis"' "$(_inventory_scalar "lynis")" "a word"
    assert_equals '"1.5"' "$(_inventory_scalar "1.5")" "a decimal is not an integer"
    assert_equals '"3 packages"' "$(_inventory_scalar "3 packages")" "a number in prose"
}

test_scalar_does_not_silently_reinterpret_a_padded_number() {
    # jq reads 007 as 7. Carrying it as a number would change the value
    # without saying so, which is the kind of quiet corruption this file exists
    # to avoid.
    assert_equals '"007"' "$(_inventory_scalar "007")" "a padded integer stays a string"
}

# ------------------------------------------------------------ typed extras

test_a_numeric_extra_is_a_number() {
    # "count": "1" would be a number inside a string, which the consumer then
    # has to parse - and can parse wrongly.
    local out
    out=$(_inventory_finding vulnerable_packages "" "1 vulnerable packages found" count 1)

    assert_equals "number" "$(jq -r '.count | type' <<< "$out")" "count is a number"
    assert_equals "1" "$(jq -r .count <<< "$out")" "and carries the measurement"
}

test_a_textual_extra_is_still_a_string() {
    local out
    out=$(_inventory_finding hardening_score "72" "72/100" tool lynis)

    assert_equals "string" "$(jq -r '.tool | type' <<< "$out")" "the tool stays a string"
    assert_equals "lynis" "$(jq -r .tool <<< "$out")" "unchanged by the typing rule"
}

# ------------------------------------------------- vulnerable package count

test_the_count_travels_beside_a_null_cell_value() {
    # The register contradicts itself about which literal means compliant, so
    # the cell stays undecided. The count is a different question.
    local out
    out=$(_inventory_finding vulnerable_packages "" "1 vulnerable packages found" count 1)

    assert_equals "null" "$(jq -r '.value | tostring' <<< "$out")" "the cell is still undecided"
    assert_equals "1" "$(jq -r .count <<< "$out")" "and the measurement survives"
    assert_equals "1 vulnerable packages found" "$(jq -r .finding <<< "$out")" "finding intact"
}

test_a_determined_zero_is_a_zero() {
    local out
    out=$(_inventory_finding vulnerable_packages "" "no vulnerable packages found" count 0)

    assert_equals "number" "$(jq -r '.count | type' <<< "$out")" "zero is a measurement"
    assert_equals "0" "$(jq -r .count <<< "$out")" "and it is zero"
}

test_an_undetermined_count_is_null() {
    local out
    out=$(_inventory_finding vulnerable_packages "" \
              "not determined - no package audit tool present" count "")

    assert_equals "null" "$(jq -r '.count | tostring' <<< "$out")" "nothing looked is not zero"
}

test_determined_and_undetermined_are_distinguishable_without_prose() {
    # The bug: on Arch and on Ubuntu the same serialised value meant opposite
    # things, and only the Dutch finding text told them apart.
    local arch ubuntu
    arch=$(_inventory_finding vulnerable_packages "" \
               "not determined - no package audit tool present" count "")
    ubuntu=$(_inventory_finding vulnerable_packages "" \
               "1 vulnerable packages found" count 1)

    assert_equals "null" "$(jq -r '.value | tostring' <<< "$arch")" "both cells are null"
    assert_equals "null" "$(jq -r '.value | tostring' <<< "$ubuntu")" "both cells are null"

    # ... and yet they are now told apart by a field, not by reading prose.
    assert_equals "null" "$(jq -r '.count | tostring' <<< "$arch")" "Arch determined nothing"
    assert_equals "1" "$(jq -r '.count | tostring' <<< "$ubuntu")" "Ubuntu determined one"
}

# ------------------------------------------------------------- whole file

write_inventory() {
    local findings
    findings=$(jq -nc \
        --argjson os "$(_inventory_finding os "NixOS 26.05 (Yarara)" "NixOS 26.05 (Yarara)")" \
        --argjson vuln "$(_inventory_finding vulnerable_packages "" "no package audit tool")" \
        --argjson score "$(_inventory_finding hardening_score "72" "72/100" tool lynis)" \
        '{os: $os, vulnerable_packages: $vuln, hardening_score: $score}')
    _write_asset_inventory_json "$INVENTORY_WORKDIR" "$@" "$findings" > /dev/null
}

test_the_file_carries_a_schema_version() {
    # The client runs ahead of the server and will keep doing so. A consumer has
    # to be able to recognise a generation it does not fully understand without
    # guessing from which keys happen to be present.
    setup_inventory_env
    write_inventory "lobos" "wtoorren" "2026-09-15" "PF50L2MR" "ThinkPad"

    local f="$INVENTORY_WORKDIR/asset-inventory.json"
    assert_equals "number" "$(jq -r '.schema_version | type' < "$f")" "the schema version is a number"
    # A document carrying `count` is a generation a version-1 consumer does not
    # fully understand, so it is not version 1.
    assert_equals "2" "$(jq -r .schema_version < "$f")" "the current generation"

    teardown_inventory_env
}

test_the_identity_block_carries_the_serial() {
    setup_inventory_env
    write_inventory "lobos" "wtoorren" "2026-09-15" "PF50L2MR" "ThinkPad P16s"

    local f="$INVENTORY_WORKDIR/asset-inventory.json"
    assert_equals "PF50L2MR" "$(jq -r .identity.serial < "$f")" "the serial is the identity"
    assert_equals "lobos" "$(jq -r .identity.hostname < "$f")" "the hostname is recorded"
    assert_equals "wtoorren" "$(jq -r .identity.username < "$f")" "and the username"

    teardown_inventory_env
}

test_an_unknown_serial_is_null_rather_than_the_string_na() {
    # The collection server matches on this. "N.A." would look like a serial and
    # match nothing, which is worse than saying there is none.
    setup_inventory_env
    write_inventory "vm-01" "root" "2026-09-15" "N.A." "N.A."

    local f="$INVENTORY_WORKDIR/asset-inventory.json"
    assert_equals "null" "$(jq -r '.identity.serial | tostring' < "$f")" "the serial is null"
    assert_equals "null" "$(jq -r '.identity.model | tostring' < "$f")" "and so is the model"

    teardown_inventory_env
}

test_the_file_is_valid_json_when_determinations_fail() {
    setup_inventory_env
    write_inventory "" "" "" "N.A." "N.A."

    local f="$INVENTORY_WORKDIR/asset-inventory.json"
    assert_success "parsing a file written from failed determinations" \
        "$(jq empty < "$f" > /dev/null 2>&1; echo $?)"

    teardown_inventory_env
}

test_the_platform_is_recorded() {
    setup_inventory_env
    write_inventory "lobos" "wtoorren" "2026-09-15" "PF50L2MR" "ThinkPad"

    local f="$INVENTORY_WORKDIR/asset-inventory.json"
    local platform
    platform=$(jq -r .platform < "$f")
    case "$platform" in
        linux|macos) assert_success "a known platform is recorded" 0 ;;
        *) assert_failure "unexpected platform '$platform'" 0 ;;
    esac

    teardown_inventory_env
}

# --------------------------------------------------------------- end to end

# Build an output directory the way an audit leaves one, with the Lynis fields
# the vulnerable-package determination reads.
# Usage: make_audit_dir <dir> <package_audit_tool_found> <vulnerable_packages_found>
make_audit_dir() {
    local dir="$1" tool="$2" count="$3"
    mkdir -p "$dir"
    jq -n --argjson tool "$tool" --argjson count "$count" \
        '{hostname: "hb-test",
          report_datetime_start: "2026-09-16 10:00:00",
          os_fullname: "Ubuntu 24.04 LTS",
          hardening_index: "72",
          package_audit_tool_found: ($tool | tostring),
          vulnerable_packages_found: ($count | tostring)}' > "$dir/lynis-report.json"
    printf '{"user":"hbtest","host":"QEMU"}\n' > "$dir/fastfetch.json"
}

# Run the real generator over a fixture directory and hand back the JSON path.
# It writes its markdown report into the working directory, so it runs in a
# throwaway one.
run_generator() {
    local dir="$1" prev
    prev="$PWD"
    cd "$INVENTORY_WORKDIR" || return 1
    generate_xlsx_asset_row_report "$dir" > /dev/null 2>&1
    cd "$prev" || return 1
}

test_end_to_end_a_counted_vulnerability_reaches_the_json() {
    # The Ubuntu case from the bug report: the audit counted one, and the
    # machine-readable record did not carry it.
    setup_inventory_env
    local dir="$INVENTORY_WORKDIR/output-hb-ubuntu-test-hbtest-16-09-2026"
    make_audit_dir "$dir" 1 1
    run_generator "$dir"

    local f="$dir/asset-inventory.json"
    assert_equals "1" "$(jq -r '.findings.vulnerable_packages.count' < "$f")" \
        "the count reaches the file"
    assert_equals "null" "$(jq -r '.findings.vulnerable_packages.value | tostring' < "$f")" \
        "and the cell stays undecided"

    teardown_inventory_env
}

test_end_to_end_no_audit_tool_leaves_the_count_undetermined() {
    # The Arch case: Lynis reports 0 vulnerable packages because nothing looked.
    setup_inventory_env
    local dir="$INVENTORY_WORKDIR/output-hb-arch-test-hbtest-16-09-2026"
    make_audit_dir "$dir" 0 0
    run_generator "$dir"

    local f="$dir/asset-inventory.json"
    assert_equals "null" "$(jq -r '.findings.vulnerable_packages.count | tostring' < "$f")" \
        "nothing looked is not a determined zero"

    teardown_inventory_env
}

test_end_to_end_a_clean_machine_reports_a_determined_zero() {
    setup_inventory_env
    local dir="$INVENTORY_WORKDIR/output-hb-clean-hbtest-16-09-2026"
    make_audit_dir "$dir" 1 0
    run_generator "$dir"

    local f="$dir/asset-inventory.json"
    assert_equals "0" "$(jq -r '.findings.vulnerable_packages.count' < "$f")" \
        "a tool looked and found none"
    assert_equals "number" "$(jq -r '.findings.vulnerable_packages.count | type' < "$f")" \
        "recorded as a number, not as null"

    teardown_inventory_env
}

test_end_to_end_the_two_platforms_are_distinguishable() {
    # One test run, two platforms, previously the same serialised value.
    setup_inventory_env
    local arch="$INVENTORY_WORKDIR/output-hb-arch-test-hbtest-16-09-2026"
    local ubuntu="$INVENTORY_WORKDIR/output-hb-ubuntu-test-hbtest-16-09-2026"
    make_audit_dir "$arch" 0 0
    make_audit_dir "$ubuntu" 1 1
    run_generator "$arch"
    run_generator "$ubuntu"

    local a u
    a=$(jq -c '.findings.vulnerable_packages | {value, count}' < "$arch/asset-inventory.json")
    u=$(jq -c '.findings.vulnerable_packages | {value, count}' < "$ubuntu/asset-inventory.json")

    assert_equals '{"value":null,"count":null}' "$a" "Arch determined nothing"
    assert_equals '{"value":null,"count":1}' "$u" "Ubuntu determined one"

    teardown_inventory_env
}

run_tests "$@"
