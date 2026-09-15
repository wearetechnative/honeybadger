#!/usr/bin/env bash
# shellcheck disable=SC2034  # HB_* overrides are consumed by lib/_library
# What the audit writes and says when there is no usable serial, and how the
# recorded serial reaches asset-inventory.txt.

set -u   # deliberately no pipefail: RUNME.sh does not set it either
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

WORK=""
STUB_BIN=""
OUT=""
ORIGINAL_PATH="$PATH"

setup() {
    reset_serial_globals
    WORK=$(mktemp -d)
    STUB_BIN="$WORK/bin"
    OUT="$WORK/output-testhost-tester-15-09-2026"
    mkdir -p "$OUT"
    link_real_tools "$STUB_BIN"
    PATH="$STUB_BIN"
    HB_SERIAL_PLATFORM="linux"
}

teardown() {
    PATH="$ORIGINAL_PATH"
    [[ -n "$WORK" && -d "$WORK" ]] && rm -rf "$WORK"
    WORK=""
}

serial_file()  { cat "$OUT/hardware-serial.txt" 2>/dev/null; }
source_file()  { cat "$OUT/hardware-serial-source.txt" 2>/dev/null; }

# --- what gets written -----------------------------------------------------

test_a_usable_serial_is_written_with_its_source() {
    setup
    printf 'PF50L2MR\n' > "$WORK/product_serial"
    HB_SYSFS_PRODUCT_SERIAL="$WORK/product_serial"

    collect_hardware_serial "$OUT"
    assert_success "collection should succeed" $?
    assert_equals "PF50L2MR" "$(serial_file)" "hardware-serial.txt"
    assert_equals "sysfs:product_serial" "$(source_file)" "hardware-serial-source.txt"
    teardown
}

test_no_source_at_all_writes_could_not_read() {
    setup

    collect_hardware_serial "$OUT"
    assert_failure "collection should not succeed" $?
    assert_equals "could-not-read" "$(serial_file)" "hardware-serial.txt"
    teardown
}

test_a_placeholder_writes_none_present() {
    setup
    printf 'Not available\n' > "$WORK/product_serial"
    HB_SYSFS_PRODUCT_SERIAL="$WORK/product_serial"

    collect_hardware_serial "$OUT"
    assert_failure "collection should not succeed" $?
    assert_equals "none-present" "$(serial_file)" "hardware-serial.txt"
    teardown
}

test_an_unusable_value_is_never_written_as_a_measurement() {
    setup
    # The macOS failure mode, reproduced through the Linux path: text that is
    # not a serial must not land in the file.
    printf 'Mac OS X\t\n' > "$WORK/product_serial"
    HB_SYSFS_PRODUCT_SERIAL="$WORK/product_serial"

    collect_hardware_serial "$OUT"
    local written
    written=$(serial_file)
    assert_equals "none-present" "$written" "hardware-serial.txt"
    ASSERTIONS=$((ASSERTIONS + 1))
    if [[ "$written" == *"Mac OS X"* ]]; then
        fail "unrelated output was written into hardware-serial.txt"
    fi
    teardown
}

test_never_writes_the_legacy_not_available_token() {
    setup
    printf 'To Be Filled By O.E.M.\n' > "$WORK/product_serial"
    HB_SYSFS_PRODUCT_SERIAL="$WORK/product_serial"

    collect_hardware_serial "$OUT"
    ASSERTIONS=$((ASSERTIONS + 1))
    if [[ "$(serial_file)" == "Not available" ]]; then
        fail "the old 'Not available' token must no longer be written"
    fi
    teardown
}

test_an_unsupported_platform_is_could_not_read() {
    setup
    HB_SERIAL_PLATFORM="unknown"

    collect_hardware_serial "$OUT"
    assert_failure "collection should not succeed" $?
    assert_equals "could-not-read" "$(serial_file)" "hardware-serial.txt"
    assert_equals "unsupported-platform" "$(source_file)" "hardware-serial-source.txt"
    teardown
}

# --- what the operator is told ---------------------------------------------

test_the_operator_is_told_the_serial_and_its_source() {
    setup
    printf 'MP1Y69AC\n' > "$WORK/product_serial"
    HB_SYSFS_PRODUCT_SERIAL="$WORK/product_serial"
    collect_hardware_serial "$OUT"

    local report
    report=$(hb_serial_report_line)
    assert_contains "$report" "MP1Y69AC" "the serial itself"
    assert_contains "$report" "sysfs:product_serial" "the source"
    teardown
}

test_could_not_read_is_reported_not_silent() {
    setup
    collect_hardware_serial "$OUT"

    local report
    report=$(hb_serial_report_line)
    assert_contains "$report" "could-not-read" "names the outcome"
    ASSERTIONS=$((ASSERTIONS + 1))
    [[ -z "$report" ]] && fail "the run must not complete silently"
    teardown
}

test_none_present_names_the_other_outcome() {
    setup
    printf 'Default string\n' > "$WORK/product_serial"
    HB_SYSFS_PRODUCT_SERIAL="$WORK/product_serial"
    collect_hardware_serial "$OUT"

    local report
    report=$(hb_serial_report_line)
    assert_contains "$report" "none-present" "names the outcome"
    assert_contains "$report" "virtual machines" "explains why this is not a defect"
    teardown
}

test_the_two_outcomes_are_reported_differently() {
    setup
    collect_hardware_serial "$OUT"
    local not_read
    not_read=$(hb_serial_report_line)

    printf 'None\n' > "$WORK/product_serial"
    HB_SYSFS_PRODUCT_SERIAL="$WORK/product_serial"
    collect_hardware_serial "$OUT"
    local not_present
    not_present=$(hb_serial_report_line)

    ASSERTIONS=$((ASSERTIONS + 1))
    if [[ "$not_read" == "$not_present" ]]; then
        fail "could-not-read and none-present must not read the same"
    fi
    teardown
}

# --- reading it back out of an output directory ----------------------------

test_reads_a_recorded_serial_back() {
    setup
    printf 'FRANDGCPA5530200H9\n' > "$OUT/hardware-serial.txt"
    printf 'dmidecode\n' > "$OUT/hardware-serial-source.txt"

    read_recorded_serial "$OUT"
    assert_success "should report a usable serial" $?
    assert_equals "FRANDGCPA5530200H9" "$HB_SERIAL_VALUE" "serial"
    assert_equals "dmidecode" "$HB_SERIAL_SOURCE" "source"
    assert_equals "ok" "$HB_SERIAL_STATUS" "status"
    teardown
}

test_reads_none_present_back_as_none_present() {
    setup
    printf 'none-present\n' > "$OUT/hardware-serial.txt"

    read_recorded_serial "$OUT"
    assert_failure "should not report a usable serial" $?
    assert_equals "none-present" "$HB_SERIAL_STATUS" "status"
    assert_equals "unknown" "$HB_SERIAL_SOURCE" "source unknown without the source file"
    teardown
}

test_a_legacy_archive_is_not_mistaken_for_data() {
    setup
    # An archive written before this chain existed
    printf 'Not available\n' > "$OUT/hardware-serial.txt"

    read_recorded_serial "$OUT"
    assert_failure "should not report a usable serial" $?
    assert_equals "could-not-read" "$HB_SERIAL_STATUS" "status"
    assert_equals "" "$HB_SERIAL_VALUE" "no value"
    teardown
}

test_a_legacy_macos_archive_is_not_mistaken_for_data() {
    setup
    printf 'Mac OS X\t\n' > "$OUT/hardware-serial.txt"

    read_recorded_serial "$OUT"
    assert_failure "should not report a usable serial" $?
    assert_equals "" "$HB_SERIAL_VALUE" "no value"
    teardown
}

test_a_missing_file_is_could_not_read() {
    setup

    read_recorded_serial "$OUT"
    assert_failure "should not report a usable serial" $?
    assert_equals "could-not-read" "$HB_SERIAL_STATUS" "status"
    teardown
}

# --- asset-inventory.txt ---------------------------------------------------

test_asset_inventory_records_the_serial_and_its_source() {
    setup
    printf 'PF50L2MR\n' > "$OUT/hardware-serial.txt"
    printf 'sysfs:product_serial\n' > "$OUT/hardware-serial-source.txt"

    generate_asset_inventory "$OUT" >/dev/null
    local inventory
    inventory=$(cat "$OUT/asset-inventory.txt")
    assert_contains "$inventory" "Serial Number" "serial row"
    assert_contains "$inventory" "PF50L2MR" "the serial"
    assert_contains "$inventory" "Serial Source" "source row"
    assert_contains "$inventory" "sysfs:product_serial" "the source"
    teardown
}

test_asset_inventory_carries_the_not_found_token_through() {
    setup
    printf 'none-present\n' > "$OUT/hardware-serial.txt"
    printf 'hardware-reports-none\n' > "$OUT/hardware-serial-source.txt"

    generate_asset_inventory "$OUT" >/dev/null
    local inventory
    inventory=$(cat "$OUT/asset-inventory.txt")
    assert_contains "$inventory" "none-present" "the outcome"
    ASSERTIONS=$((ASSERTIONS + 1))
    if [[ "$inventory" == *"Serial Number                        | Not available"* ]]; then
        fail "asset inventory still reports the old 'Not available' token"
    fi
    teardown
}

run_tests "$@"
