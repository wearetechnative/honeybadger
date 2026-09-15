#!/usr/bin/env bash
# shellcheck disable=SC2034  # HB_* overrides are consumed by lib/_library
# is_usable_serial() against the values actually found in the archives on
# compute2-prod, plus the firmware placeholders the collection server rejects.

set -u   # deliberately no pipefail: RUNME.sh does not set it either
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_accepts_the_serials_found_on_compute2() {
    assert_usable_serial "PF50L2MR"            # lobos-wtoorren
    assert_usable_serial "MP1Y69AC"            # pankhuri
    assert_usable_serial "FRANDGCPA5530200H9"  # Jeroen-jeroen
    assert_usable_serial "FRANMDCPA750850030"  # lego2-pim
    assert_usable_serial "PF50L2ML"            # mathijs-p16s
    assert_usable_serial "C02ZK1TSLVDQ"        # an Apple serial
}

test_rejects_the_placeholders_the_server_rejects() {
    assert_unusable_serial "Not available"
    assert_unusable_serial "Not available (VM or unknown hardware)"
    assert_unusable_serial "To Be Filled By O.E.M."
    assert_unusable_serial "To Be Filled"
    assert_unusable_serial "Default string"
    assert_unusable_serial "Not Specified"
    assert_unusable_serial "System Serial Number"
    assert_unusable_serial "None"
    assert_unusable_serial "Unknown"
}

test_placeholder_match_ignores_case() {
    assert_unusable_serial "none"
    assert_unusable_serial "NONE"
    assert_unusable_serial "UnKnOwN"
}

test_rejects_the_macos_fragment_that_looked_like_data() {
    # What MBP-van-pim-pim actually submitted: a fragment of unrelated output
    assert_unusable_serial "Mac OS X	"
    assert_unusable_serial "Mac OS X"
}

test_rejects_all_zeroes_at_any_length() {
    assert_unusable_serial "0"
    assert_unusable_serial "00000000"
    assert_unusable_serial "0000000000000000"
}

test_rejects_empty_and_whitespace_only() {
    assert_unusable_serial ""
    assert_unusable_serial " "
    assert_unusable_serial "	"
    assert_unusable_serial "
"
}

test_rejects_any_value_carrying_whitespace() {
    # A serial is one token. Leading or trailing whitespace means the value
    # came out of a parser that grabbed more than the serial.
    assert_unusable_serial " PF50L2MR"
    assert_unusable_serial "PF50L2MR "
    assert_unusable_serial "PF50 L2MR"
    assert_unusable_serial "Serial Number: PF50L2MR"
}

test_rejects_the_tokens_this_tool_writes_itself() {
    # Re-reading an output directory must not mistake our own marker for data
    assert_unusable_serial "could-not-read"
    assert_unusable_serial "none-present"
}

test_accepts_serials_that_merely_contain_zeroes() {
    assert_usable_serial "0PF50L2MR"
    assert_usable_serial "FRANMDCPA750850030"
}

run_tests "$@"
