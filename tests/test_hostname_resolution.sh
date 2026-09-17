#!/usr/bin/env bash
# shellcheck disable=SC2034  # HB_* overrides are consumed by lib/_library
# The hostname source chain with each source stubbed in turn, plus a guard
# against the `local x=$(cmd)` pattern that made the original failure silent.
#
# Every test runs with PATH pointing at a stub directory, so "uname is not
# installed" can be tested honestly on a machine that has it - and so that no
# test ever reads the real hostname of the machine running the suite.

set -u   # deliberately no pipefail: RUNME.sh does not set it either
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

WORK=""
STUB_BIN=""
ORIGINAL_PATH="$PATH"
ORIGINAL_HOSTNAME="${HOSTNAME:-}"

setup() {
    WORK=$(mktemp -d)
    STUB_BIN="$WORK/bin"
    link_real_tools "$STUB_BIN"
    # No uname and no hostname(1) unless a test puts one there. This is the
    # stock-Arch condition for hostname(1), reproduced without an Arch host.
    rm -f "$STUB_BIN/uname" "$STUB_BIN/hostname"
    PATH="$STUB_BIN"
    HOSTNAME=""
    HB_HOSTNAME_FILE="$WORK/nonexistent-hostname"
}

teardown() {
    PATH="$ORIGINAL_PATH"
    HOSTNAME="$ORIGINAL_HOSTNAME"
    HB_HOSTNAME_FILE=""
    [[ -n "$WORK" && -d "$WORK" ]] && rm -rf "$WORK"
    WORK=""
}

# ---------------------------------------------------------------------------
# Source chain
# ---------------------------------------------------------------------------

test_uname_is_the_first_source() {
    setup
    stub_tool "$STUB_BIN" uname 'echo "kernel-name"'
    HOSTNAME="shell-name"
    printf 'file-name\n' > "$WORK/hostname"
    HB_HOSTNAME_FILE="$WORK/hostname"

    local result status
    result=$(hb_resolve_short_hostname)
    status=$?

    assert_success "uname should resolve" "$status"
    assert_equals "kernel-name" "$result" "uname -n must win over the later sources"
    teardown
}

test_shell_variable_used_when_uname_is_absent() {
    setup
    HOSTNAME="shell-name"
    printf 'file-name\n' > "$WORK/hostname"
    HB_HOSTNAME_FILE="$WORK/hostname"

    local result status
    result=$(hb_resolve_short_hostname)
    status=$?

    assert_success "\$HOSTNAME should resolve" "$status"
    assert_equals "shell-name" "$result" "\$HOSTNAME must win over /etc/hostname"
    teardown
}

test_hostname_file_is_the_last_resort() {
    setup
    printf 'file-name\n' > "$WORK/hostname"
    HB_HOSTNAME_FILE="$WORK/hostname"

    local result status
    result=$(hb_resolve_short_hostname)
    status=$?

    assert_success "/etc/hostname should resolve" "$status"
    assert_equals "file-name" "$result" "value must come from the hostname file"
    teardown
}

test_hostname_file_reads_only_its_first_line() {
    setup
    printf 'first\nsecond\n' > "$WORK/hostname"
    HB_HOSTNAME_FILE="$WORK/hostname"

    local result
    result=$(hb_resolve_short_hostname)

    assert_equals "first" "$result" "only the first line of the file is the hostname"
    teardown
}

test_hostname_file_without_a_trailing_newline_still_resolves() {
    setup
    # `read` returns non-zero at EOF without a delimiter even though it has
    # read the name. The value, not the status, is what decides.
    printf 'no-newline' > "$WORK/hostname"
    HB_HOSTNAME_FILE="$WORK/hostname"

    local result status
    result=$(hb_resolve_short_hostname)
    status=$?

    assert_success "a file without a trailing newline should still resolve" "$status"
    assert_equals "no-newline" "$result" "the name is read despite read's status"
    teardown
}

test_no_hostname_tool_is_invoked() {
    setup
    # A hostname(1) that fails loudly if anything calls it. On a stock Arch
    # host it would not exist at all; here it exists only to be caught.
    stub_tool "$STUB_BIN" hostname 'echo "hostname(1) was invoked" >&2; exit 1'
    stub_tool "$STUB_BIN" uname 'echo "kernel-name"'

    local result stderr_file status
    stderr_file="$WORK/stderr"
    result=$(hb_resolve_short_hostname 2>"$stderr_file")
    status=$?

    assert_success "resolution should succeed without hostname(1)" "$status"
    assert_equals "kernel-name" "$result" "resolved name"
    assert_equals "" "$(cat "$stderr_file")" "hostname(1) must never be invoked"
    teardown
}

# ---------------------------------------------------------------------------
# Shortening
# ---------------------------------------------------------------------------

test_fully_qualified_name_is_shortened() {
    setup
    stub_tool "$STUB_BIN" uname 'echo "web01.example.com"'

    local result
    result=$(hb_resolve_short_hostname)

    assert_equals "web01" "$result" "the domain must be cut off, as hostname -s did"
    teardown
}

test_name_without_a_domain_is_unchanged() {
    setup
    stub_tool "$STUB_BIN" uname 'echo "lobos"'

    local result
    result=$(hb_resolve_short_hostname)

    assert_equals "lobos" "$result" "a bare name is left alone"
    teardown
}

test_shell_variable_is_shortened_too() {
    setup
    HOSTNAME="web02.example.com"

    local result
    result=$(hb_resolve_short_hostname)

    assert_equals "web02" "$result" "\$HOSTNAME is shortened like every other source"
    teardown
}

# ---------------------------------------------------------------------------
# Usability
# ---------------------------------------------------------------------------

test_usable_hostname_accepts_ordinary_names() {
    ASSERTIONS=$((ASSERTIONS + 3))
    hb_usable_hostname "lobos"     || fail "'lobos' should be usable"
    hb_usable_hostname "web-01"    || fail "'web-01' should be usable"
    hb_usable_hostname "localhost" || fail "'localhost' should be usable"
}

test_usable_hostname_rejects_unfilenameable_values() {
    ASSERTIONS=$((ASSERTIONS + 5))
    hb_usable_hostname ""            && fail "empty should be rejected"
    hb_usable_hostname "two words"   && fail "whitespace should be rejected"
    hb_usable_hostname "a	b"        && fail "a tab should be rejected"
    hb_usable_hostname "../escape"   && fail "a path separator should be rejected"
    hb_usable_hostname "host/name"   && fail "a slash should be rejected"
    return 0
}

test_empty_source_falls_through_to_the_next() {
    setup
    stub_tool "$STUB_BIN" uname 'echo ""'
    HOSTNAME="shell-name"

    local result
    result=$(hb_resolve_short_hostname)

    assert_equals "shell-name" "$result" "an empty uname must not win"
    teardown
}

test_bare_newline_from_uname_falls_through() {
    setup
    stub_tool "$STUB_BIN" uname 'printf "\n"'
    printf 'file-name\n' > "$WORK/hostname"
    HB_HOSTNAME_FILE="$WORK/hostname"

    local result
    result=$(hb_resolve_short_hostname)

    assert_equals "file-name" "$result" "a newline-only uname must not win"
    teardown
}

test_whitespace_bearing_source_falls_through() {
    setup
    stub_tool "$STUB_BIN" uname 'echo "two words"'
    HOSTNAME="shell-name"

    local result
    result=$(hb_resolve_short_hostname)

    assert_equals "shell-name" "$result" "a name with whitespace must not win"
    teardown
}

test_slash_bearing_source_falls_through() {
    setup
    stub_tool "$STUB_BIN" uname 'echo "etc/passwd"'
    HOSTNAME="shell-name"

    local result
    result=$(hb_resolve_short_hostname)

    assert_equals "shell-name" "$result" "a name with a slash must not win"
    teardown
}

test_empty_hostname_file_falls_back_to_uname() {
    setup
    stub_tool "$STUB_BIN" uname 'echo "kernel-name"'
    : > "$WORK/hostname"
    HB_HOSTNAME_FILE="$WORK/hostname"

    local result
    result=$(hb_resolve_short_hostname)

    assert_equals "kernel-name" "$result" "an empty file must not stop a usable uname"
    teardown
}

test_localhost_is_accepted_rather_than_substituted() {
    setup
    stub_tool "$STUB_BIN" uname 'echo "localhost"'

    local result
    result=$(hb_resolve_short_hostname)

    assert_equals "localhost" "$result" "localhost is what the machine is called"
    teardown
}

# ---------------------------------------------------------------------------
# Failure path
# ---------------------------------------------------------------------------

test_failure_returns_non_zero_and_prints_nothing() {
    setup
    # No uname, no $HOSTNAME, no readable hostname file.
    local result status
    result=$(hb_resolve_short_hostname)
    status=$?

    assert_failure "resolution should fail when no source answers" "$status"
    assert_equals "" "$result" "nothing is printed when no name could be resolved"
    teardown
}

test_failing_uname_does_not_stop_a_later_source() {
    setup
    stub_tool "$STUB_BIN" uname 'exit 1'
    HOSTNAME="shell-name"

    local result status
    result=$(hb_resolve_short_hostname)
    status=$?

    assert_success "a failing uname must not end the chain" "$status"
    assert_equals "shell-name" "$result" "the next source answers"
    teardown
}

# ---------------------------------------------------------------------------
# Guards against the pattern coming back
# ---------------------------------------------------------------------------

test_runme_does_not_combine_local_with_command_substitution() {
    local offenders
    # `local x=$(cmd)` returns the builtin's status, not the command's, which
    # is exactly how the missing hostname(1) stayed invisible. Scoped to
    # RUNME.sh: the occurrences in lib/_library pair a command that may
    # legitimately produce nothing with 2>/dev/null and a fallback, where the
    # masked status is the intent.
    offenders=$(grep -nE '^[[:space:]]*(local|declare|export|readonly)[[:space:]]+[A-Za-z_][A-Za-z_0-9]*=\$\(' \
                    "$REPO_ROOT/RUNME.sh" || true)

    ASSERTIONS=$((ASSERTIONS + 1))
    if [[ -n "$offenders" ]]; then
        fail "RUNME.sh declares and assigns in one statement, hiding the command's exit status:
$offenders"
    fi
}

test_no_shipped_shell_source_invokes_the_hostname_tool() {
    local sources=("$REPO_ROOT/RUNME.sh" "$REPO_ROOT/lib/_library")
    local script
    for script in "$REPO_ROOT"/lib/*.sh; do
        [[ -f "$script" ]] && sources+=("$script")
    done

    # Every shell source the audit ships, not just RUNME.sh: scoping this to
    # one file is how the second call in lib/_library survived the change that
    # removed the first. There is no deliberate use of hostname(1) anywhere -
    # unlike the `local x=$(cmd)` guard above, this one has no exception to
    # carve out.
    #
    # Two shapes are matched: the `-s` and `-f` flags the tool was called with
    # here, and a bare `$(hostname)`, which is the cheapest way to bring the
    # dependency back and which the flag-anchored pattern would let through.
    #
    # Full-line comments are stripped first. lib/_library documents in prose
    # what `hostname -s` used to do, next to the resolver that replaced it;
    # that sentence is this guard working, not an offence against it. A call
    # with a trailing comment is still caught, because only lines whose first
    # non-blank character is `#` are dropped.
    local offenders
    offenders=$(grep -nE '(\$\(|`)[[:space:]]*hostname([[:space:]]|\)|`)|(^|[^[:alnum:]_.$-])hostname[[:space:]]+-[sf]' \
                    "${sources[@]}" | grep -vE ':[[:space:]]*#' || true)

    ASSERTIONS=$((ASSERTIONS + 1))
    if [[ -n "$offenders" ]]; then
        fail "a shipped shell source still shells out to hostname(1), which Arch does not install:
$offenders"
    fi
}

run_tests "$@"
