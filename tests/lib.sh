#!/usr/bin/env bash
# shellcheck disable=SC2034  # HB_* overrides are consumed by lib/_library
# Minimal assertion helpers for the honeybadger shell test suite.
#
# A test file sources this, defines functions named test_*, and ends with
# `run_tests "$@"`. Each test runs in the current shell, so a test that changes
# globals must clean up after itself - reset_serial_globals() is there for that.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

# shellcheck source=/dev/null
source "$REPO_ROOT/lib/_library"

ASSERTIONS=0
FAILURES=0
CURRENT_TEST=""

fail() {
    FAILURES=$((FAILURES + 1))
    echo "    ✗ $CURRENT_TEST: $1" >&2
}

assert_equals() {
    local expected="$1" actual="$2" message="${3:-}"
    ASSERTIONS=$((ASSERTIONS + 1))
    if [[ "$expected" != "$actual" ]]; then
        fail "${message:-value mismatch}: expected '$expected', got '$actual'"
        return 1
    fi
    return 0
}

assert_success() {
    local message="${1:-command should succeed}"
    local status="$2"
    ASSERTIONS=$((ASSERTIONS + 1))
    if [[ "$status" -ne 0 ]]; then
        fail "$message: exit status $status"
        return 1
    fi
    return 0
}

assert_failure() {
    local message="${1:-command should fail}"
    local status="$2"
    ASSERTIONS=$((ASSERTIONS + 1))
    if [[ "$status" -eq 0 ]]; then
        fail "$message: exit status 0"
        return 1
    fi
    return 0
}

assert_contains() {
    local haystack="$1" needle="$2" message="${3:-}"
    ASSERTIONS=$((ASSERTIONS + 1))
    if [[ "$haystack" != *"$needle"* ]]; then
        fail "${message:-substring missing}: '$needle' not found in '$haystack'"
        return 1
    fi
    return 0
}

assert_usable_serial() {
    local value="$1"
    ASSERTIONS=$((ASSERTIONS + 1))
    if ! is_usable_serial "$value"; then
        fail "'$value' should be accepted as a usable serial"
        return 1
    fi
    return 0
}

assert_unusable_serial() {
    local value="$1"
    ASSERTIONS=$((ASSERTIONS + 1))
    if is_usable_serial "$value"; then
        fail "'$value' should be rejected as a serial"
        return 1
    fi
    return 0
}

# Reset every global and override the serial chain reads, so one test cannot
# leak state into the next and no test ever touches the real machine.
reset_serial_globals() {
    HB_SERIAL_VALUE=""
    HB_SERIAL_SOURCE=""
    HB_SERIAL_STATUS=""
    HB_SERIAL_PLATFORM=""
    HB_SYSFS_PRODUCT_SERIAL="/nonexistent/product_serial"
    HB_SYSFS_BOARD_SERIAL="/nonexistent/board_serial"
    HB_OS_RELEASE_FILE="/nonexistent/os-release"
}

# Populate a directory with symlinks to the real tools the library needs, so a
# test can set PATH to that directory alone. Without this there is no honest
# way to test "dmidecode is not installed" on a machine that has it - and no
# way at all to test the NixOS fallback on a machine that is not NixOS.
# Usage: link_real_tools <dir>
link_real_tools() {
    local dir="$1" tool src
    mkdir -p "$dir"
    for tool in bash cat tr awk grep sed mkdir chmod rm ln printf; do
        src=$(command -v "$tool" 2>/dev/null) || continue
        ln -sf "$src" "$dir/$tool"
    done
}

# Build a stub directory that shadows the real tools for the duration of a test.
# Usage: stub_tool <dir> <name> <shell body>
stub_tool() {
    local dir="$1" name="$2" body="$3"
    mkdir -p "$dir"
    {
        echo '#!/usr/bin/env bash'
        echo "$body"
    } > "$dir/$name"
    chmod +x "$dir/$name"
}

run_tests() {
    local suite
    suite="$(basename "${BASH_SOURCE[1]}")"
    echo "  $suite"

    local fn
    for fn in $(declare -F | awk '{print $3}' | grep '^test_' | sort); do
        CURRENT_TEST="$fn"
        "$fn"
    done

    if [[ $FAILURES -gt 0 ]]; then
        echo "    $FAILURES failed assertion(s) out of $ASSERTIONS"
        return 1
    fi
    echo "    $ASSERTIONS assertion(s) passed"
    return 0
}
