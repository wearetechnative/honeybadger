#!/usr/bin/env bash
# shellcheck disable=SC2034  # SERVER_* and STUB_* are consumed by lib/_library
#                              and by the curl stub respectively
# What the client sends to the collection server, and how it reads the answer.
#
# Every test here runs against a stubbed curl: the point is which report types
# and files leave the client, and which HTTP answers it treats as success -
# never whether a real server is reachable.

set -u   # deliberately no pipefail: RUNME.sh does not set it either
# shellcheck source=tests/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

WORKDIR=""

# A curl that answers whatever the test asks it to, and records the arguments
# it was called with so a test can assert on the headers and the payload.
install_curl_stub() {
    local dir="$1"
    link_real_tools "$dir"
    # link_real_tools covers the serial chain's needs; submission also shells
    # out to these.
    local tool src
    for tool in hostname whoami mktemp tar gzip head tail tr date env basename dirname; do
        src=$(command -v "$tool" 2>/dev/null) || continue
        ln -sf "$src" "$dir/$tool"
    done
    stub_tool "$dir" curl '
args_file="${STUB_ARGS_FILE:?}"
printf "%s\n" "$@" >> "$args_file"

out=""
prev=""
for arg in "$@"; do
    if [[ "$prev" == "--output" ]]; then
        out="$arg"
    fi
    prev="$arg"
done
[[ -n "$out" ]] && printf "%s" "${STUB_BODY:-}" > "$out"

printf "%s" "${STUB_HTTP_CODE:-200}"
exit "${STUB_CURL_EXIT:-0}"
'
}

# A submission environment that touches nothing real: its own working
# directory, its own HOME, and a PATH holding only the stubbed tools. Without
# the HOME and cwd change, load_server_config() would source the repository's
# own .honeybadger.conf and aim the tests at the production server.
setup_submission_env() {
    WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/honeybadger-submit-test-XXXXXX")
    install_curl_stub "$WORKDIR/bin"

    export STUB_ARGS_FILE="$WORKDIR/curl-args.txt"
    export STUB_HTTP_CODE="200"
    export STUB_BODY=""
    export STUB_CURL_EXIT="0"
    : > "$STUB_ARGS_FILE"

    ORIGINAL_PATH="$PATH"
    ORIGINAL_HOME="$HOME"
    ORIGINAL_PWD="$PWD"
    PATH="$WORKDIR/bin"
    HOME="$WORKDIR"
    cd "$WORKDIR" || return 1

    SERVER_ENABLED="true"
    SERVER_URL="http://localhost:7199/"
    SERVER_TOKEN="test-token"
    SERVER_TIMEOUT="5"
    SERVER_RETRY_COUNT="1"
    DRY_RUN="false"
}

teardown_submission_env() {
    cd "$ORIGINAL_PWD" || true
    PATH="$ORIGINAL_PATH"
    HOME="$ORIGINAL_HOME"
    [[ -n "$WORKDIR" && -d "$WORKDIR" ]] && rm -rf "$WORKDIR"
    WORKDIR=""
}

# An output directory shaped like the one the audit writes.
make_output_dir() {
    local dir="$WORKDIR/output-testhost-tester-15-09-2026"
    mkdir -p "$dir"
    printf '%s\n' '{"os":"NixOS 26.05","kernel":"6.18.50","host":"ThinkPad"}' > "$dir/fastfetch.json"
    printf '%s\n' '{"lynis_version":"3.1.1","hardening_index":"70"}' > "$dir/lynis-report.json"
    echo "$dir"
}

curl_args() {
    cat "$STUB_ARGS_FILE"
}

# ------------------------------------------------------------------ responses

test_classify_treats_every_2xx_as_stored() {
    assert_equals "success" "$(classify_submission_response 200 0)" "200 is success"
    assert_equals "success" "$(classify_submission_response 201 0)" "201 is success"
    assert_equals "success" "$(classify_submission_response 204 0)" "204 is success"
}

test_classify_names_207_a_partial_submission() {
    # badgersbay answers 207 when it stored the submission but could not match
    # it to an asset register entry. The evidence is on disk; resending it
    # would only store it twice.
    assert_equals "partial" "$(classify_submission_response 207 0)" "207 is partial"
}

test_classify_does_not_retry_client_errors() {
    assert_equals "client-error" "$(classify_submission_response 400 0)" "400"
    assert_equals "client-error" "$(classify_submission_response 401 0)" "401"
    assert_equals "client-error" "$(classify_submission_response 413 0)" "413"
}

test_classify_retries_server_and_transport_failures() {
    assert_equals "retry" "$(classify_submission_response 500 0)" "500"
    assert_equals "retry" "$(classify_submission_response 502 0)" "502"
    assert_equals "retry" "$(classify_submission_response 000 7)" "connection refused"
    assert_equals "retry" "$(classify_submission_response 200 28)" "timeout mid-transfer"
}

test_server_message_is_lifted_out_of_the_error_page() {
    local body_file
    body_file=$(mktemp "${TMPDIR:-/tmp}/honeybadger-body-XXXXXX")
    cat > "$body_file" <<'HTML'
<!DOCTYPE HTML>
<html lang="en">
    <body>
        <h1>Error response</h1>
        <p>Error code: 400</p>
        <p>Message: Invalid report type 'neofetch'. Supported types: lynis, fastfetch, trivy, vulnix.</p>
    </body>
</html>
HTML
    local output
    output=$(report_server_response "$body_file")
    rm -f "$body_file"

    assert_contains "$output" "Invalid report type 'neofetch'" "reason is shown"
    assert_contains "$output" "Supported types: lynis, fastfetch" "supported types are shown"
    if [[ "$output" == *"<p>"* ]]; then
        fail "the error page markup should not be printed: $output"
    fi
    ASSERTIONS=$((ASSERTIONS + 1))
}

test_json_error_body_is_shown_as_is() {
    local body_file
    body_file=$(mktemp "${TMPDIR:-/tmp}/honeybadger-body-XXXXXX")
    printf '%s' '{"error": "Invalid authentication token"}' > "$body_file"

    local output
    output=$(report_server_response "$body_file")
    rm -f "$body_file"

    assert_contains "$output" "Invalid authentication token" "JSON error is shown"
}

# ------------------------------------------------------------- what is sent

test_the_archive_carries_the_files_the_server_derives_types_from() {
    # The submission never names a report type: the server derives it from the
    # file name inside the archive. So the names the audit writes have to be
    # the names the server recognises.
    setup_submission_env
    local dir
    dir=$(make_output_dir)

    local tarball="$WORKDIR/honeybadger-testhost-tester-15-09-2026.tar.gz"
    tar czf "$tarball" -C "$WORKDIR" "$(basename "$dir")" 2>/dev/null

    local members
    members=$(tar tzf "$tarball")

    assert_contains "$members" "$HB_SYSINFO_REPORT_FILE" "the archive carries the system info file"
    assert_contains "$members" "$HB_HARDENING_REPORT_FILE" "the archive carries the hardening file"

    teardown_submission_env
}

# ------------------------------------------------------ missing and rejected

test_tar_submission_accepts_a_partial_answer() {
    setup_submission_env
    local dir
    dir=$(make_output_dir)
    local tarball="$WORKDIR/honeybadger-testhost-tester-15-09-2026.tar.gz"
    tar czf "$tarball" -C "$WORKDIR" "$(basename "$dir")" 2>/dev/null

    STUB_HTTP_CODE="207"
    STUB_BODY='{"status": "partial", "unmatched_reason": "serial_not_in_register"}'

    local output status
    output=$(submit_tar_file "$tarball" 2>&1)
    status=$?

    assert_success "a 207 tar submission" "$status"
    assert_contains "$output" "partial" "the partial result is named"

    local args
    args=$(curl_args)
    assert_contains "$args" "/submit-tar" "the tar goes to the tar endpoint"

    teardown_submission_env
}

test_tar_submission_reports_the_server_reason_on_rejection() {
    setup_submission_env
    local dir
    dir=$(make_output_dir)
    local tarball="$WORKDIR/honeybadger-testhost-tester-15-09-2026.tar.gz"
    tar czf "$tarball" -C "$WORKDIR" "$(basename "$dir")" 2>/dev/null

    STUB_HTTP_CODE="401"
    STUB_BODY='{"error": "Invalid authentication token"}'

    local output status
    output=$(submit_tar_file "$tarball" 2>&1)
    status=$?

    assert_failure "a rejected tar submission" "$status"
    assert_contains "$output" "Invalid authentication token" "the server's reason reaches the operator"

    teardown_submission_env
}

test_submission_sends_authentication_and_identity_headers() {
    setup_submission_env
    local dir
    dir=$(make_output_dir)
    local tarball="$WORKDIR/honeybadger-testhost-tester-15-09-2026.tar.gz"
    tar czf "$tarball" -C "$WORKDIR" "$(basename "$dir")" 2>/dev/null

    submit_tar_file "$tarball" > /dev/null 2>&1
    local args
    args=$(curl_args)

    assert_contains "$args" "Authorization: Bearer test-token" "the bearer token is sent"
    assert_contains "$args" "X-Hostname: " "the hostname is sent"
    assert_contains "$args" "X-Username: " "the username is sent"

    teardown_submission_env
}

test_a_missing_archive_is_a_failure() {
    setup_submission_env

    local output status
    output=$(submit_tar_file "$WORKDIR/does-not-exist.tar.gz" 2>&1)
    status=$?

    assert_failure "submitting an archive that is not there" "$status"
    assert_contains "$output" "does-not-exist.tar.gz" "the missing file is named"

    teardown_submission_env
}

test_the_single_report_path_is_gone() {
    # It submitted to an endpoint with no concept of a hardware serial, so its
    # submissions could not be attributed to an asset in the ISO register.
    if declare -f submit_all_reports > /dev/null 2>&1; then
        assert_failure "submit_all_reports should not exist" 0
    else
        assert_success "the per-report submission path is removed" 0
    fi
}

run_tests "$@"
