#!/usr/bin/env bash
# shellcheck disable=SC2034  # HB_* overrides are consumed by lib/_library
# The macOS parsers against captured ioreg and system_profiler output, and the
# macOS chain with each source stubbed in turn.

set -u   # deliberately no pipefail: RUNME.sh does not set it either
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

FIXTURES="$TESTS_DIR/fixtures"
WORK=""
STUB_BIN=""
ORIGINAL_PATH="$PATH"

setup() {
    reset_serial_globals
    WORK=$(mktemp -d)
    STUB_BIN="$WORK/bin"
    link_real_tools "$STUB_BIN"
    PATH="$STUB_BIN"
    HB_SERIAL_PLATFORM="macos"
}

teardown() {
    PATH="$ORIGINAL_PATH"
    [[ -n "$WORK" && -d "$WORK" ]] && rm -rf "$WORK"
    WORK=""
}

traced() { cat "$WORK/trace" 2>/dev/null; }

stub_from_fixture() {
    local name="$1" fixture="$2"
    stub_tool "$STUB_BIN" "$name" "echo $name >> '$WORK/trace'
cat '$FIXTURES/$fixture'"
}

# --- parsers, fed real captured output ------------------------------------

test_ioreg_parser_reads_the_platform_serial() {
    local serial
    serial=$(hb_parse_ioreg_serial < "$FIXTURES/ioreg-IOPlatformExpertDevice.txt")
    assert_equals "C02ZK1TSLVDQ" "$serial" "ioreg serial"
}

test_ioreg_parser_ignores_the_other_properties() {
    # IOPlatformUUID sits right below it and is not a serial
    local serial
    serial=$(hb_parse_ioreg_serial < "$FIXTURES/ioreg-IOPlatformExpertDevice.txt")
    ASSERTIONS=$((ASSERTIONS + 1))
    if [[ "$serial" == *"-"* ]]; then
        fail "parser picked up the UUID instead of the serial: $serial"
    fi
}

test_ioreg_parser_yields_nothing_on_a_virtual_machine() {
    local serial
    serial=$(hb_parse_ioreg_serial < "$FIXTURES/ioreg-no-serial.txt")
    assert_equals "" "$serial" "empty IOPlatformSerialNumber"
}

test_system_profiler_parser_reads_the_serial_number_label() {
    local serial
    serial=$(hb_parse_system_profiler_serial < "$FIXTURES/system_profiler-SPHardwareDataType.txt")
    assert_equals "C02ZK1TSLVDQ" "$serial" "system_profiler serial"
}

test_system_profiler_parser_stops_at_the_first_match() {
    # "Serial Number" must not drag in the Hardware UUID line below it
    local serial
    serial=$(hb_parse_system_profiler_serial < "$FIXTURES/system_profiler-SPHardwareDataType.txt")
    assert_unusable_serial "$serial " # sanity: the parser returns a bare token
    assert_usable_serial "$serial"
}

test_system_profiler_parser_returns_the_placeholder_verbatim() {
    local serial
    serial=$(hb_parse_system_profiler_serial < "$FIXTURES/system_profiler-placeholder.txt")
    assert_equals "Not available" "$serial" "placeholder passed through to validation"
    assert_unusable_serial "$serial"
}

test_the_old_implementation_result_would_be_rejected() {
    # MBP-van-pim-pim submitted "Mac OS X<TAB>". Whatever produced it, the
    # validation gate is what stops it from being written as a measurement.
    assert_unusable_serial "Mac OS X	"
}

# --- the chain -------------------------------------------------------------

test_ioreg_is_the_first_source() {
    setup
    stub_from_fixture ioreg ioreg-IOPlatformExpertDevice.txt
    stub_from_fixture system_profiler system_profiler-SPHardwareDataType.txt

    hb_collect_serial_macos
    assert_success "chain should succeed" $?
    assert_equals "C02ZK1TSLVDQ" "$HB_SERIAL_VALUE" "serial"
    assert_equals "ioreg:IOPlatformSerialNumber" "$HB_SERIAL_SOURCE" "source"
    assert_equals "ioreg" "$(traced)" "system_profiler should not be reached"
    teardown
}

test_system_profiler_is_the_fallback() {
    setup
    stub_from_fixture ioreg ioreg-no-serial.txt
    stub_from_fixture system_profiler system_profiler-SPHardwareDataType.txt

    hb_collect_serial_macos
    assert_success "chain should succeed" $?
    assert_equals "C02ZK1TSLVDQ" "$HB_SERIAL_VALUE" "serial"
    assert_equals "system_profiler:SPHardwareDataType" "$HB_SERIAL_SOURCE" "source"
    assert_equals "ioreg
system_profiler" "$(traced)" "both sources should have been consulted"
    teardown
}

test_system_profiler_used_when_ioreg_is_absent() {
    setup
    stub_from_fixture system_profiler system_profiler-SPHardwareDataType.txt

    hb_collect_serial_macos
    assert_equals "C02ZK1TSLVDQ" "$HB_SERIAL_VALUE" "serial"
    assert_equals "system_profiler:SPHardwareDataType" "$HB_SERIAL_SOURCE" "source"
    teardown
}

test_a_virtual_mac_reports_none_present() {
    setup
    stub_from_fixture ioreg ioreg-no-serial.txt
    stub_from_fixture system_profiler system_profiler-placeholder.txt

    hb_collect_serial_macos
    assert_failure "chain should not succeed" $?
    assert_equals "none-present" "$HB_SERIAL_STATUS" "status"
    assert_equals "" "$HB_SERIAL_VALUE" "no value should be produced"
    teardown
}

test_neither_tool_available_is_could_not_read() {
    setup

    hb_collect_serial_macos
    assert_failure "chain should not succeed" $?
    assert_equals "could-not-read" "$HB_SERIAL_STATUS" "status"
    teardown
}

test_a_failing_ioreg_does_not_count_as_an_answer() {
    setup
    stub_tool "$STUB_BIN" ioreg "exit 1"

    hb_collect_serial_macos
    assert_equals "could-not-read" "$HB_SERIAL_STATUS" "status"
    teardown
}

run_tests "$@"
