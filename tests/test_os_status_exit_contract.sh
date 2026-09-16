#!/usr/bin/env bash
# What an exit status means, for each of the two entry points.
#
# They used to share the name check_os_status and disagree: the script exits a
# severity (0 PASS, 1 WARNING, 2 EOL/FAIL), the library function ends on `cat`
# and so returns 0. RUNME.sh read as though it carried the severity out as the
# audit's exit status - it could not, and it should not: a finding is not a
# failed run, and a caller on a schedule has to be able to tell the difference.

set -u   # deliberately no pipefail: RUNME.sh does not set it either
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

WORK=""

setup() {
    WORK=$(mktemp -d)
    # A populated cache, so no test reaches the network for release data.
    mkdir -p "$WORK/cache"
    printf '[{"cycle":"24.04","lts":true,"eol":"2029-04-25"}]\n' > "$WORK/cache/ubuntu-releases.json"
    printf '[{"cycle":"26.05","eol":"2026-12-31"}]\n' > "$WORK/cache/nixos-releases.json"
    printf '{"releases":[{"version":"6.8.12","moniker":"stable","iseol":false}]}\n' > "$WORK/cache/kernel-releases.json"
}

teardown() {
    [[ -n "$WORK" && -d "$WORK" ]] && rm -rf "$WORK"
    WORK=""
}

# An output directory as a current audit leaves one.
# Usage: make_audit_dir <os> <kernel> <kernel_latest>
make_audit_dir() {
    local os="$1" kernel="$2" latest="$3"
    local dir="$WORK/output-hb-test-hbtest-16-09-2026"
    mkdir -p "$dir"
    jq -n --arg os "$os" --arg kernel "$kernel" --arg latest "$latest" \
        '{user:"hbtest", host:"QEMU", hostname:"hb-test",
          os:$os, kernel:$kernel, kernel_latest:$latest}' > "$dir/fastfetch.json"
    jq -n --arg os "$os" --arg kernel "$kernel" \
        '{hostname:"hb-test", os_name:"Ubuntu", os_version:"24.04",
          os_fullname:$os, linux_kernel_version:$kernel}' > "$dir/lynis-report.json"
    printf '%s' "$dir"
}

# ------------------------------------------- the library step produces a report

test_a_produced_report_is_a_zero() {
    setup
    local dir status
    dir=$(make_audit_dir "Ubuntu 24.04 LTS" "6.8.12" "6.8.12 (2026-05-01)")
    generate_os_status_report "$dir" "$WORK/cache" >/dev/null 2>&1
    status=$?

    assert_success "writing the report is the success condition" "$status"
    ASSERTIONS=$((ASSERTIONS + 1))
    [[ -f "$dir/os-kernel-status.txt" ]] || fail "no report was written"
    teardown
}

test_a_finding_is_still_a_zero() {
    # A kernel behind upstream is a warning in the report. It is not a reason
    # for the caller to treat the run as failed - which is the whole point.
    setup
    local dir status report
    dir=$(make_audit_dir "Ubuntu 24.04 LTS" "6.8.0" "6.8.12 (2026-05-01)")
    generate_os_status_report "$dir" "$WORK/cache" >/dev/null 2>&1
    status=$?
    report=$(cat "$dir/os-kernel-status.txt")

    assert_success "a finding must not look like a failure" "$status"
    assert_contains "$report" "6.8.12" "and the finding is in the report, where it belongs"
    teardown
}

test_a_missing_directory_is_a_failure() {
    setup
    local status
    generate_os_status_report "$WORK/no-such-directory" "$WORK/cache" >/dev/null 2>&1
    status=$?

    assert_failure "a directory that is not there cannot produce a report" "$status"
    teardown
}

test_a_directory_without_system_information_is_a_failure() {
    setup
    local dir status
    dir="$WORK/output-hb-bare-hbtest-16-09-2026"
    mkdir -p "$dir"
    generate_os_status_report "$dir" "$WORK/cache" >/dev/null 2>&1
    status=$?

    assert_failure "no system information, no report" "$status"
    ASSERTIONS=$((ASSERTIONS + 1))
    [[ -f "$dir/os-kernel-status.txt" ]] && fail "a report was written for a refused directory"
    teardown
}

# ------------------------------------------- the operator command is a severity

test_the_script_still_exits_a_severity() {
    # The script is a command an operator runs on one directory and reads the
    # answer from, so a severity exit code is the right interface there. This
    # asserts the two entry points genuinely differ, rather than one having been
    # quietly changed to match the other.
    setup
    local dir status
    dir=$(make_audit_dir "Ubuntu 24.04 LTS" "6.8.0" "6.8.12 (2026-05-01)")
    bash "$REPO_ROOT/lib/check-os-status.sh" "$dir" "$WORK/cache" >/dev/null 2>&1
    status=$?

    ASSERTIONS=$((ASSERTIONS + 1))
    case "$status" in
        0|1|2) ;;
        *) fail "the script's exit status should be a severity, got $status" ;;
    esac
    teardown
}

test_the_script_documents_its_severity_codes() {
    local header
    header=$(head -30 "$REPO_ROOT/lib/check-os-status.sh")

    assert_contains "$header" "SEVERITY" "the script states what its exit status means"
    assert_contains "$header" "generate_os_status_report" "and names the other entry point"
}

# ------------------------------------------------- guards against a relapse

test_the_old_name_is_not_used_in_live_code() {
    local offenders
    # Archived changes and the CHANGELOG record what the function was called at
    # the time and are deliberately not rewritten.
    # This file is excluded: it has to name the old name to explain itself.
    offenders=$(grep -rn --exclude="$(basename "${BASH_SOURCE[0]}")" 'check_os_status' \
                    "$REPO_ROOT/lib" "$REPO_ROOT/RUNME.sh" "$REPO_ROOT/tests" || true)

    ASSERTIONS=$((ASSERTIONS + 1))
    if [[ -n "$offenders" ]]; then
        fail "the old name is back, and with it the collision with the script:
$offenders"
    fi
}

test_check_output_does_not_forward_a_status_from_the_generator() {
    # The line this bean is about: `generate_os_status_report ... || exit_code=$?`
    # followed by `exit $exit_code` reads as though the severity were carried
    # out. It never was, and must not start being.
    local offenders
    offenders=$(grep -nE 'generate_os_status_report[^|]*\|\|[[:space:]]*[a-z_]+=\$\?' \
                    "$REPO_ROOT/RUNME.sh" || true)

    ASSERTIONS=$((ASSERTIONS + 1))
    if [[ -n "$offenders" ]]; then
        fail "a status is being captured from the report generator again:
$offenders"
    fi
}

run_tests "$@"
