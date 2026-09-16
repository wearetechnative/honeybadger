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
    out=$(_inventory_finding firewall "N.A." "firewallstatus niet vast te stellen")

    assert_equals "null" "$(jq -r '.value | tostring' <<< "$out")" "the value is null"
    assert_contains "$(jq -r .finding <<< "$out")" "niet vast te stellen" "the reason survives"
}

test_a_declined_value_is_null_with_the_finding_intact() {
    # Vulnerable packages: the audit deliberately asserts no value, because the
    # spreadsheet contradicts itself about which one means compliant. That
    # refusal is information and has to survive serialisation.
    local out
    out=$(_inventory_finding vulnerable_packages "" "niet vastgesteld - geen package audit tool aanwezig")

    assert_equals "null" "$(jq -r '.value | tostring' <<< "$out")" "the value is null"
    assert_contains "$(jq -r .finding <<< "$out")" "geen package audit tool" "the reason says why"
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

# ------------------------------------------------------------- whole file

write_inventory() {
    local findings
    findings=$(jq -nc \
        --argjson os "$(_inventory_finding os "NixOS 26.05 (Yarara)" "NixOS 26.05 (Yarara)")" \
        --argjson vuln "$(_inventory_finding vulnerable_packages "" "geen package audit tool")" \
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

run_tests "$@"
