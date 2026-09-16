#!/usr/bin/env bash
# Who ran the audit, and when.
#
# Both used to be recovered by parsing the output directory's name, which joins
# hostname, username and date with "-" and lets all three contain "-". Every
# hyphenated hostname shifted the fields, and asset-inventory.json - the file
# the collection server reads - named a user that does not exist on the machine.
#
# The directory names exercised here are real: every output directory and
# report filename this repository holds, plus the two acceptance-test hosts.

set -u   # deliberately no pipefail: RUNME.sh does not set it either
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

WORK=""

setup() {
    WORK=$(mktemp -d)
    HB_DIR_HOSTNAME=""
    HB_DIR_USERNAME=""
    HB_DIR_DATE=""
}

teardown() {
    [[ -n "$WORK" && -d "$WORK" ]] && rm -rf "$WORK"
    WORK=""
}

# Build an output directory carrying the fetch file a real audit would leave.
# Usage: make_output_dir <dirname> [fetch_file_name] [username]
make_output_dir() {
    local dirname="$1" fetch="${2:-}" user="${3:-}"
    local dir="$WORK/$dirname"
    mkdir -p "$dir"
    if [[ -n "$fetch" ]]; then
        case "$fetch" in
            *.json) printf '{"user":"%s","host":"ThinkPad","kernel":"6.1"}\n' "$user" > "$dir/$fetch" ;;
            *.txt)  printf '%s@somehost\nHost: ThinkPad\nKernel: 6.1\n' "$user" > "$dir/$fetch" ;;
        esac
    fi
    printf '%s' "$dir"
}

# --------------------------------------------------------------- parsing

assert_parse() {
    local dirname="$1" hostname="$2" username="$3" date="$4"
    if ! hb_parse_output_dirname "$dirname"; then
        ASSERTIONS=$((ASSERTIONS + 1))
        fail "'$dirname' should parse"
        return 1
    fi
    assert_equals "$hostname" "$HB_DIR_HOSTNAME" "$dirname: hostname"
    assert_equals "$username" "$HB_DIR_USERNAME" "$dirname: username"
    assert_equals "$date" "$HB_DIR_DATE" "$dirname: date"
}

test_hostname_without_a_hyphen() {
    # The case the old regex got right, and the only shape it was written for.
    assert_parse "output-lobos-wtoorren-15-09-2026" "lobos" "wtoorren" "15-09-2026"
    assert_parse "output-Jeroen-jeroen-14-09-2026" "Jeroen" "jeroen" "14-09-2026"
}

test_hostname_with_one_hyphen() {
    # The old regex returned the right username here by luck - the hostname's
    # last segment happens to equal it - but still got the date wrong.
    assert_parse "output-technative-casper-casper-26-03-2026" \
        "technative-casper" "casper" "26-03-2026"
}

test_hostname_with_several_hyphens() {
    # In this repository as honeybadger-van-pim-pim-07-04-2026-actions.md,
    # a report named after a user called "van".
    assert_parse "output-mbp-van-pim-pim-07-04-2026" \
        "mbp-van-pim" "pim" "07-04-2026"
}

test_hostname_with_many_hyphens_and_digits() {
    # The name the bug report singles out. The old regex said "prakash".
    assert_parse "output-pankhuri-prakash-IdeaPad-5-14ARE05-root-02-04-2026" \
        "pankhuri-prakash-IdeaPad-5-14ARE05" "root" "02-04-2026"
}

test_macos_hostname_with_hyphens() {
    # In this repository as
    # honeybadger-Pro-van-Sebastiaan-basanneveld-20-04-2026-compliance.md.
    assert_parse "output-MacBook-Pro-van-Sebastiaan-basanneveld-20-04-2026" \
        "MacBook-Pro-van-Sebastiaan" "basanneveld" "20-04-2026"
}

test_the_two_acceptance_test_hosts() {
    # Ubuntu 24.04 in QEMU and a stock Arch cloud image: two platforms, two
    # hostnames, the same corruption. The old regex said "ubuntu" and "arch".
    assert_parse "output-hb-ubuntu-test-hbtest-16-09-2026" \
        "hb-ubuntu-test" "hbtest" "16-09-2026"
    assert_parse "output-hb-arch-test-hbtest-16-09-2026" \
        "hb-arch-test" "hbtest" "16-09-2026"
}

test_a_name_that_is_not_an_output_directory_does_not_parse() {
    local status
    hb_parse_output_dirname "output-weird"
    status=$?
    assert_failure "a name with no date suffix must not parse" "$status"

    hb_parse_output_dirname "some-other-directory"
    status=$?
    assert_failure "an unrelated name must not parse" "$status"
}

test_a_name_with_no_username_does_not_parse() {
    local status
    hb_parse_output_dirname "output-lobos-15-09-2026"
    status=$?
    assert_failure "hostname and date alone must not parse" "$status"
}

test_a_failed_parse_leaves_no_partial_fields() {
    hb_parse_output_dirname "output-lobos-wtoorren-15-09-2026"
    hb_parse_output_dirname "output-weird"

    assert_equals "" "$HB_DIR_HOSTNAME" "hostname cleared"
    assert_equals "" "$HB_DIR_USERNAME" "username cleared"
    assert_equals "" "$HB_DIR_DATE" "date cleared"
}

# ------------------------------------------------------ username sources

test_username_comes_from_fastfetch() {
    setup
    local dir
    dir=$(make_output_dir "output-hb-ubuntu-test-hbtest-16-09-2026" fastfetch.json hbtest)

    assert_equals "hbtest" "$(hb_audit_username "$dir")" "the audit's own record wins"
    teardown
}

test_fastfetch_wins_over_the_directory_name() {
    setup
    # A directory name that would decode to something else entirely.
    local dir
    dir=$(make_output_dir "output-pankhuri-prakash-IdeaPad-5-14ARE05-root-02-04-2026" \
                          fastfetch.json root)

    assert_equals "root" "$(hb_audit_username "$dir")" "the recorded user is used"
    teardown
}

test_username_containing_a_hyphen_survives() {
    setup
    # The one case no directory-name parse can ever recover, which is why the
    # audit data is the source rather than the fallback.
    local dir
    dir=$(make_output_dir "output-lobos-jan-pieter-15-09-2026" fastfetch.json jan-pieter)

    assert_equals "jan-pieter" "$(hb_audit_username "$dir")" "the full username"
    teardown
}

test_neofetch_json_when_there_is_no_fastfetch() {
    setup
    local dir
    dir=$(make_output_dir "output-mbp-van-pim-pim-07-04-2026" neofetch.json pim)

    assert_equals "pim" "$(hb_audit_username "$dir")" "archives from before the switch"
    teardown
}

test_neofetch_txt_when_there_is_no_json() {
    setup
    local dir
    dir=$(make_output_dir "output-mbp-van-pim-pim-07-04-2026" neofetch.txt pim)

    assert_equals "pim" "$(hb_audit_username "$dir")" "archives from before either was JSON"
    teardown
}

test_fastfetch_is_preferred_over_neofetch() {
    setup
    local dir
    dir=$(make_output_dir "output-lobos-wtoorren-15-09-2026" fastfetch.json newuser)
    printf '{"user":"olduser"}\n' > "$dir/neofetch.json"

    assert_equals "newuser" "$(hb_audit_username "$dir")" "the current source wins"
    teardown
}

test_directory_name_is_the_last_resort() {
    setup
    # No fetch file at all. The parse is used - and now gets it right.
    local dir
    dir=$(make_output_dir "output-hb-ubuntu-test-hbtest-16-09-2026")

    assert_equals "hbtest" "$(hb_audit_username "$dir")" "recovered from the name"
    teardown
}

test_an_empty_user_field_falls_through() {
    setup
    local dir
    dir=$(make_output_dir "output-hb-ubuntu-test-hbtest-16-09-2026" fastfetch.json "")

    assert_equals "hbtest" "$(hb_audit_username "$dir")" "an empty field is not an answer"
    teardown
}

test_no_source_at_all_reports_failure() {
    setup
    local dir result status
    dir=$(make_output_dir "output-weird")
    result=$(hb_audit_username "$dir")
    status=$?

    assert_failure "an unnameable directory should report failure" "$status"
    assert_equals "" "$result" "and print nothing"
    teardown
}

# -------------------------------------------------------- report naming

test_report_named_for_the_real_user() {
    setup
    local dir
    dir=$(make_output_dir "output-mbp-van-pim-pim-07-04-2026" neofetch.json pim)

    assert_equals "honeybadger-pim-07-04-2026-compliance.md" \
        "$(hb_report_basename "$dir" compliance)" "compliance report"
    assert_equals "honeybadger-pim-07-04-2026-actions.md" \
        "$(hb_report_basename "$dir" actions)" "actions report"
    assert_equals "honeybadger-pim-07-04-2026-xlsx.md" \
        "$(hb_report_basename "$dir" xlsx)" "xlsx report"
    teardown
}

test_all_three_reports_carry_the_same_identity() {
    setup
    local dir c a x
    dir=$(make_output_dir "output-pankhuri-prakash-IdeaPad-5-14ARE05-root-02-04-2026" \
                          fastfetch.json root)
    c=$(hb_report_basename "$dir" compliance)
    a=$(hb_report_basename "$dir" actions)
    x=$(hb_report_basename "$dir" xlsx)

    assert_equals "honeybadger-root-02-04-2026-compliance.md" "$c" "compliance"
    assert_equals "${c%compliance.md}actions.md" "$a" "actions matches compliance"
    assert_equals "${c%compliance.md}xlsx.md" "$x" "xlsx matches compliance"
    teardown
}

test_a_correct_name_is_left_alone() {
    # Hosts that were already right must keep the filenames they had.
    setup
    local dir
    dir=$(make_output_dir "output-lobos-wtoorren-15-09-2026" fastfetch.json wtoorren)

    assert_equals "honeybadger-wtoorren-15-09-2026-compliance.md" \
        "$(hb_report_basename "$dir" compliance)" "unchanged for a hyphen-free hostname"
    teardown
}

test_unknown_identity_falls_back_to_the_kind_and_today() {
    setup
    local dir
    dir=$(make_output_dir "output-weird")

    assert_equals "honeybadger-xlsx-$(date +%d-%m-%Y).md" \
        "$(hb_report_basename "$dir" xlsx)" "named after the kind, not a guessed user"
    teardown
}

# --------------------------------------------------- the two files agree

test_the_inventory_txt_and_json_name_the_same_user() {
    # The emitter's comment says the two cannot disagree. Before this change
    # they did, for exactly this directory shape.
    setup
    local dir owner
    dir=$(make_output_dir "output-hb-ubuntu-test-hbtest-16-09-2026" fastfetch.json hbtest)

    # asset-inventory.txt takes the owner from hb_audit_username(), and so does
    # the username handed to _write_asset_inventory_json().
    owner=$(hb_audit_username "$dir")

    _write_asset_inventory_json "$dir" "hb-ubuntu-test" "$owner" \
        "2026-09-16" "N.A." "N.A." '{}' > /dev/null

    assert_equals "hbtest" "$owner" "the owner asset-inventory.txt records"
    assert_equals "hbtest" "$(jq -r .identity.username < "$dir/asset-inventory.json")" \
        "and the username asset-inventory.json records"
    teardown
}

# ------------------------------------------------- guard against a relapse

test_the_hyphen_blind_regex_is_not_reintroduced() {
    local offenders
    # Matched only where it is used as a pattern, so the comment in
    # lib/_library explaining why it was removed does not trip this.
    offenders=$(grep -rn '=~.*output-(\[^-\]' "$REPO_ROOT/lib" "$REPO_ROOT/RUNME.sh" || true)

    ASSERTIONS=$((ASSERTIONS + 1))
    if [[ -n "$offenders" ]]; then
        fail "the hyphen-blind directory-name regex is back:
$offenders"
    fi
}

run_tests "$@"
