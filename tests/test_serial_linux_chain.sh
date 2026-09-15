#!/usr/bin/env bash
# shellcheck disable=SC2034  # HB_* overrides are consumed by lib/_library
# The Linux chain with each source stubbed in turn, asserting both that the
# right source wins and that later sources are never consulted when an earlier
# one succeeds.

set -u   # deliberately no pipefail: RUNME.sh does not set it either
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

WORK=""
STUB_BIN=""
ORIGINAL_PATH="$PATH"

setup() {
    reset_serial_globals
    WORK=$(mktemp -d)
    STUB_BIN="$WORK/bin"
    # Only the tools the library itself needs: no dmidecode, no nix, and no
    # accidental contact with the machine running the tests.
    link_real_tools "$STUB_BIN"
    PATH="$STUB_BIN"
    HB_SERIAL_PLATFORM="linux"
}

teardown() {
    PATH="$ORIGINAL_PATH"
    [[ -n "$WORK" && -d "$WORK" ]] && rm -rf "$WORK"
    WORK=""
}

# Record every tool invocation so a test can assert a later step was skipped.
trace_file() { echo "$WORK/trace"; }
traced() { cat "$(trace_file)" 2>/dev/null; }

stub_dmidecode() {
    stub_tool "$STUB_BIN" dmidecode "echo dmidecode >> '$WORK/trace'
$1"
}

stub_nix() {
    stub_tool "$STUB_BIN" nix "echo nix >> '$WORK/trace'
$1"
    # hb_running_on_nixos() must say yes before the nix branch is reached
    printf 'ID=nixos\nNAME=NixOS\n' > "$WORK/os-release"
    HB_OS_RELEASE_FILE="$WORK/os-release"
}

write_sysfs() {
    local name="$1" content="$2"
    printf '%s\n' "$content" > "$WORK/$name"
    case "$name" in
        product_serial) HB_SYSFS_PRODUCT_SERIAL="$WORK/$name" ;;
        board_serial)   HB_SYSFS_BOARD_SERIAL="$WORK/$name" ;;
    esac
}

test_product_serial_is_the_first_source() {
    setup
    write_sysfs product_serial "PF50L2MR"
    write_sysfs board_serial "MP1Y69AC"
    stub_dmidecode "echo SHOULD-NOT-BE-USED"

    hb_collect_serial_linux
    assert_success "chain should succeed" $?
    assert_equals "PF50L2MR" "$HB_SERIAL_VALUE" "serial"
    assert_equals "sysfs:product_serial" "$HB_SERIAL_SOURCE" "source"
    assert_equals "ok" "$HB_SERIAL_STATUS" "status"
    assert_equals "" "$(traced)" "no later source should be reached"
    teardown
}

test_board_serial_when_product_serial_is_empty() {
    setup
    write_sysfs product_serial ""
    write_sysfs board_serial "MP1Y69AC"
    stub_dmidecode "echo SHOULD-NOT-BE-USED"

    hb_collect_serial_linux
    assert_success "chain should succeed" $?
    assert_equals "MP1Y69AC" "$HB_SERIAL_VALUE" "serial"
    assert_equals "sysfs:board_serial" "$HB_SERIAL_SOURCE" "source"
    assert_equals "" "$(traced)" "dmidecode should not be reached"
    teardown
}

test_board_serial_when_product_serial_is_a_placeholder() {
    setup
    write_sysfs product_serial "To Be Filled By O.E.M."
    write_sysfs board_serial "FRANDGCPA5530200H9"

    hb_collect_serial_linux
    assert_equals "FRANDGCPA5530200H9" "$HB_SERIAL_VALUE" "serial"
    assert_equals "sysfs:board_serial" "$HB_SERIAL_SOURCE" "source"
    teardown
}

test_dmidecode_when_neither_sysfs_path_is_readable() {
    setup
    # Both sysfs paths stay at the nonexistent defaults from reset_serial_globals
    stub_dmidecode "echo PF50L2ML"

    hb_collect_serial_linux
    assert_success "chain should succeed" $?
    assert_equals "PF50L2ML" "$HB_SERIAL_VALUE" "serial"
    assert_equals "dmidecode" "$HB_SERIAL_SOURCE" "source"
    assert_equals "dmidecode" "$(traced)" "dmidecode should have been called once"
    teardown
}

test_nix_is_the_last_resort_and_only_on_nixos() {
    setup
    stub_nix "echo FRANMDCPA750850030"

    hb_collect_serial_linux
    assert_success "chain should succeed" $?
    assert_equals "FRANMDCPA750850030" "$HB_SERIAL_VALUE" "serial"
    assert_equals "nix:dmidecode" "$HB_SERIAL_SOURCE" "source"
    teardown
}

test_nix_is_skipped_when_dmidecode_already_answered() {
    setup
    stub_dmidecode "echo PF50L2MR"
    stub_nix "echo SHOULD-NOT-BE-USED"

    hb_collect_serial_linux
    assert_equals "PF50L2MR" "$HB_SERIAL_VALUE" "serial"
    assert_equals "dmidecode" "$(traced)" "nix should not be reached"
    teardown
}

test_nix_is_skipped_when_the_system_is_not_nixos() {
    setup
    stub_tool "$STUB_BIN" nix "echo nix >> '$WORK/trace'; echo PF50L2MR"
    printf 'ID=ubuntu\nNAME=Ubuntu\n' > "$WORK/os-release"
    HB_OS_RELEASE_FILE="$WORK/os-release"

    hb_collect_serial_linux
    assert_failure "chain should not succeed" $?
    assert_equals "" "$(traced)" "nix should not be reached on a non-NixOS system"
    assert_equals "could-not-read" "$HB_SERIAL_STATUS" "status"
    teardown
}

test_no_source_at_all_is_could_not_read() {
    setup

    hb_collect_serial_linux
    assert_failure "chain should not succeed" $?
    assert_equals "could-not-read" "$HB_SERIAL_STATUS" "status"
    assert_equals "" "$HB_SERIAL_VALUE" "no value should be produced"
    teardown
}

test_a_source_that_answers_with_a_placeholder_is_none_present() {
    setup
    # The virtual machine case: sysfs is there, the firmware simply has nothing
    write_sysfs product_serial "Not Specified"
    write_sysfs board_serial ""

    hb_collect_serial_linux
    assert_failure "chain should not succeed" $?
    assert_equals "none-present" "$HB_SERIAL_STATUS" "status"
    teardown
}

test_all_zeroes_from_sysfs_is_none_present() {
    setup
    write_sysfs product_serial "00000000"

    hb_collect_serial_linux
    assert_equals "none-present" "$HB_SERIAL_STATUS" "status"
    teardown
}

test_dmidecode_answering_a_placeholder_is_none_present() {
    setup
    stub_dmidecode "echo 'Not available'"

    hb_collect_serial_linux
    assert_equals "none-present" "$HB_SERIAL_STATUS" "status"
    teardown
}

test_a_failing_dmidecode_does_not_count_as_an_answer() {
    setup
    stub_dmidecode "exit 1"

    hb_collect_serial_linux
    assert_equals "could-not-read" "$HB_SERIAL_STATUS" "status"
    teardown
}

test_trailing_newline_from_sysfs_is_stripped() {
    setup
    printf 'PF50L2MR\n\n' > "$WORK/product_serial"
    HB_SYSFS_PRODUCT_SERIAL="$WORK/product_serial"

    hb_collect_serial_linux
    assert_equals "PF50L2MR" "$HB_SERIAL_VALUE" "serial"
    teardown
}

test_dmidecode_is_not_a_hard_dependency() {
    # RUNME.sh must not list dmidecode in checkdeps: a machine where sysfs
    # works would otherwise be aborted for a tool it does not need.
    ASSERTIONS=$((ASSERTIONS + 1))
    if grep -qE '^\s*checkdeps\s+"?dmidecode' "$REPO_ROOT/RUNME.sh"; then
        fail "dmidecode must not be a checkdeps dependency"
    fi
}

run_tests "$@"
