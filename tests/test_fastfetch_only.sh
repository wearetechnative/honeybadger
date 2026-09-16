#!/usr/bin/env bash
# System information comes from fastfetch.json and nothing else.
#
# The client stopped producing neofetch.json, neofetch.txt and fastfetch.txt,
# and the collection server accepts only fastfetch.json. Reading the retired
# formats anyway kept a second shape alive in the code that most needs one -
# and the legacy path carried no kernel_latest, so a directory that took it
# produced a report whose kernel comparison was silently absent.

set -u   # deliberately no pipefail: RUNME.sh does not set it either
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

WORK=""

setup() {
    WORK=$(mktemp -d)
}

teardown() {
    [[ -n "$WORK" && -d "$WORK" ]] && rm -rf "$WORK"
    WORK=""
}

# A directory as a current audit leaves it.
make_current_dir() {
    local dir="$WORK/output-hb-test-hbtest-16-09-2026"
    mkdir -p "$dir"
    printf '{"user":"hbtest","host":"QEMU","os":"Ubuntu 24.04 LTS","kernel":"6.8.0-45-generic","kernel_latest":"6.8.12 (2026-05-01)","hostname":"hb-test","packages":"1234 (dpkg)"}\n' \
        > "$dir/fastfetch.json"
    printf '%s' "$dir"
}

# A directory as it was left before the fastfetch migration.
# Usage: make_legacy_dir <legacy filename>
make_legacy_dir() {
    local legacy="$1"
    local dir="$WORK/output-hb-old-hbtest-02-04-2026"
    mkdir -p "$dir"
    case "$legacy" in
        *.json) printf '{"user":"olduser","host":"ThinkPad","os":"Ubuntu 22.04 LTS","kernel":"5.15.0-generic"}\n' > "$dir/$legacy" ;;
        *.txt)  printf 'olduser@hb-old\nOS: Ubuntu 22.04 LTS\nHost: ThinkPad\nKernel: 5.15.0-generic\n' > "$dir/$legacy" ;;
    esac
    printf '%s' "$dir"
}

# --------------------------------------------------------------- the gate

test_a_current_directory_is_accepted() {
    setup
    local dir status
    dir=$(make_current_dir)
    require_fastfetch_json "$dir" 2>/dev/null
    status=$?

    assert_success "a directory with fastfetch.json is accepted" "$status"
    teardown
}

test_a_directory_without_system_information_is_refused() {
    setup
    local dir status
    dir="$WORK/output-hb-empty-hbtest-16-09-2026"
    mkdir -p "$dir"
    require_fastfetch_json "$dir" 2>/dev/null
    status=$?

    assert_failure "no fastfetch.json means no system information" "$status"
    teardown
}

test_the_error_names_the_file_and_the_command() {
    setup
    local dir err
    dir="$WORK/output-hb-empty-hbtest-16-09-2026"
    mkdir -p "$dir"
    err=$(require_fastfetch_json "$dir" 2>&1 >/dev/null)

    assert_contains "$err" "fastfetch.json" "the missing file is named"
    assert_contains "$err" "RUNME.sh audit" "and the command that produces it"
    teardown
}

# ------------------------------------------------- legacy is not a fallback

test_neofetch_json_is_not_a_fallback() {
    setup
    local dir status
    dir=$(make_legacy_dir neofetch.json)
    require_fastfetch_json "$dir" 2>/dev/null
    status=$?

    assert_failure "neofetch.json must not stand in for fastfetch.json" "$status"
    teardown
}

test_neofetch_txt_is_not_a_fallback() {
    setup
    local dir status
    dir=$(make_legacy_dir neofetch.txt)
    require_fastfetch_json "$dir" 2>/dev/null
    status=$?

    assert_failure "neofetch.txt must not stand in for fastfetch.json" "$status"
    teardown
}

test_fastfetch_txt_is_not_a_fallback() {
    setup
    local dir status
    dir=$(make_legacy_dir fastfetch.txt)
    require_fastfetch_json "$dir" 2>/dev/null
    status=$?

    assert_failure "the text format must not stand in for the JSON one" "$status"
    teardown
}

test_a_legacy_directory_is_told_what_it_is() {
    # "fastfetch.json is missing" on a directory that plainly holds system
    # information is confusing unless the message says why it does not count.
    setup
    local dir err
    dir=$(make_legacy_dir neofetch.json)
    err=$(require_fastfetch_json "$dir" 2>&1 >/dev/null)

    assert_contains "$err" "neofetch.json" "the retired format is named"
    assert_contains "$err" "retired format" "and identified as retired"
    teardown
}

# ----------------------------------------------- extraction reads one file

test_os_and_kernel_come_from_fastfetch_json() {
    setup
    local dir
    dir=$(make_current_dir)
    extract_os_info "$dir"

    assert_equals "Ubuntu" "$OS_NAME" "OS name from fastfetch.json"
    assert_equals "24.04" "$OS_VERSION" "OS version from fastfetch.json"
    assert_equals "6.8.0" "$KERNEL_VERSION" "kernel from fastfetch.json"
    teardown
}

test_extraction_ignores_a_legacy_file() {
    # Previously neofetch.json would have been read here and produced a
    # complete-looking result with no kernel_latest behind it.
    setup
    local dir
    dir=$(make_legacy_dir neofetch.json)
    extract_os_info "$dir"

    assert_equals "" "$OS_NAME" "nothing is extracted from a retired format"
    assert_equals "" "$KERNEL_VERSION" "including the kernel"
    teardown
}

test_extraction_ignores_a_legacy_text_file() {
    setup
    local dir
    dir=$(make_legacy_dir neofetch.txt)
    extract_os_info "$dir"

    assert_equals "" "$OS_NAME" "the text format is not parsed"
    teardown
}

# ------------------------------------------------- the rest of the client

test_the_username_comes_from_fastfetch_only() {
    setup
    local dir result status
    dir=$(make_legacy_dir neofetch.json)
    result=$(hb_audit_username "$dir")
    status=$?

    # The directory name is still parsed - that is the remaining fallback - but
    # neofetch.json is not read for the user it happens to contain.
    assert_success "the directory name still names a user" "$status"
    assert_equals "hbtest" "$result" "from the name, not from neofetch.json"
    teardown
}

test_current_directories_still_resolve_from_the_fetch_file() {
    setup
    local dir
    dir=$(make_current_dir)

    assert_equals "hbtest" "$(hb_audit_username "$dir")" "unchanged for a current directory"
    teardown
}

test_check_os_status_refuses_a_legacy_directory() {
    setup
    local dir status
    dir=$(make_legacy_dir neofetch.json)
    check_os_status "$dir" "$WORK/cache" >/dev/null 2>&1
    status=$?

    assert_failure "analysis does not run without system information" "$status"
    teardown
}

test_check_os_status_writes_nothing_into_a_refused_directory() {
    # The refusal happens before the report file is opened, so a directory the
    # client will not analyse is left exactly as it was found.
    setup
    local dir
    dir=$(make_legacy_dir neofetch.json)
    check_os_status "$dir" "$WORK/cache" >/dev/null 2>&1

    ASSERTIONS=$((ASSERTIONS + 1))
    if [[ -f "$dir/os-kernel-status.txt" ]]; then
        fail "a report was written into a directory that was refused"
    fi
    teardown
}

# ------------------------------------------- guard against a reintroduction

test_the_client_does_not_read_retired_formats() {
    local offenders
    # Matched where a retired filename is read, not where it is named in a
    # message. Windows is out of scope: AUDIT.ps1 still runs neofetch, which is
    # bean honeybadger-k80g.
    # shellcheck disable=SC2016  # a grep pattern: the $ is literal, not an expansion
    offenders=$(grep -nE '"\$(output_dir|OUTPUT_DIR)/(neofetch\.json|neofetch\.txt|fastfetch\.txt)"' \
                    "$REPO_ROOT/lib/_library" "$REPO_ROOT/lib/check-os-status.sh" \
                    "$REPO_ROOT/RUNME.sh" || true)

    ASSERTIONS=$((ASSERTIONS + 1))
    if [[ -n "$offenders" ]]; then
        fail "a retired system information format is being read again:
$offenders"
    fi
}

run_tests "$@"
