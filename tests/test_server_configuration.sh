#!/usr/bin/env bash
# Where the client's server settings come from, and which source wins.
#
# The file used to be sourced after the defaults were applied, so it always won
# and an environment variable could never take effect. That mattered beyond
# convenience: DRY_RUN is a safety control, and it could not be switched on from
# the environment when the config file had it off.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$TESTS_DIR/lib.sh"

CONFIG_WORKDIR=""

setup_config_env() {
    CONFIG_WORKDIR="$(mktemp -d)"
    # Keep the search order away from any real configuration.
    ORIGINAL_HOME="$HOME"
    HOME="$CONFIG_WORKDIR/home"
    mkdir -p "$HOME"
    ORIGINAL_PWD="$PWD"
    cd "$CONFIG_WORKDIR" || return 1

    unset HONEYBADGER_CONFIG
    local name
    for name in "${HB_CONFIG_SETTINGS[@]}"; do
        unset "$name"
    done
}

teardown_config_env() {
    cd "$ORIGINAL_PWD" || true
    HOME="$ORIGINAL_HOME"
    [[ -n "$CONFIG_WORKDIR" ]] && rm -rf "$CONFIG_WORKDIR"
    CONFIG_WORKDIR=""
    unset HONEYBADGER_CONFIG
    local name
    for name in "${HB_CONFIG_SETTINGS[@]}"; do
        unset "$name"
    done
}

write_config() {
    cat > "$1"
}

# ------------------------------------------------------------- precedence

test_environment_wins_over_the_config_file() {
    setup_config_env
    write_config "$CONFIG_WORKDIR/c.conf" <<'EOF'
SERVER_URL=http://from-file/
SERVER_TOKEN=file-token
EOF

    SERVER_URL="http://from-environment/"
    load_server_config "$CONFIG_WORKDIR/c.conf" > /dev/null

    assert_equals "http://from-environment/" "$SERVER_URL" "the environment wins"
    assert_equals "file-token" "$SERVER_TOKEN" "a setting only the file has still comes from the file"

    teardown_config_env
}

test_the_file_supplies_what_the_environment_does_not() {
    setup_config_env
    write_config "$CONFIG_WORKDIR/c.conf" <<'EOF'
SERVER_URL=http://from-file/
SERVER_TIMEOUT=99
EOF

    load_server_config "$CONFIG_WORKDIR/c.conf" > /dev/null

    assert_equals "http://from-file/" "$SERVER_URL" "the file value is used"
    assert_equals "99" "$SERVER_TIMEOUT" "and so is the file's timeout"

    teardown_config_env
}

test_a_setting_in_neither_takes_the_built_in_default() {
    setup_config_env
    write_config "$CONFIG_WORKDIR/c.conf" <<'EOF'
SERVER_URL=http://from-file/
EOF

    load_server_config "$CONFIG_WORKDIR/c.conf" > /dev/null

    assert_equals "3" "$SERVER_RETRY_COUNT" "the built-in retry count is used"
    assert_equals "false" "$DRY_RUN" "and the built-in dry-run default"

    teardown_config_env
}

test_an_empty_environment_value_is_a_value() {
    # Exporting a setting as an empty string is a choice, not an absence. A
    # deliberately empty token must not be quietly refilled from the file.
    setup_config_env
    write_config "$CONFIG_WORKDIR/c.conf" <<'EOF'
SERVER_TOKEN=file-token
EOF

    SERVER_TOKEN=""
    load_server_config "$CONFIG_WORKDIR/c.conf" > /dev/null

    assert_equals "" "$SERVER_TOKEN" "the empty value survives"

    teardown_config_env
}

test_dry_run_can_be_switched_on_from_the_environment() {
    # This is the case that made the old order dangerous: a dry run that
    # submitted for real, because the file said DRY_RUN=false.
    setup_config_env
    write_config "$CONFIG_WORKDIR/c.conf" <<'EOF'
DRY_RUN=false
SERVER_URL=http://from-file/
EOF

    DRY_RUN="true"
    load_server_config "$CONFIG_WORKDIR/c.conf" > /dev/null

    assert_equals "true" "$DRY_RUN" "a dry run stays a dry run"

    teardown_config_env
}

# --------------------------------------------------------- naming a file

test_an_explicit_file_skips_the_search_order() {
    setup_config_env
    write_config "./.honeybadger.conf" <<'EOF'
SERVER_URL=http://working-directory/
EOF
    write_config "$CONFIG_WORKDIR/named.conf" <<'EOF'
SERVER_URL=http://named/
EOF

    load_server_config "$CONFIG_WORKDIR/named.conf" > /dev/null

    assert_equals "http://named/" "$SERVER_URL" "the named file is used"

    teardown_config_env
}

test_honeybadger_config_names_a_file_from_the_environment() {
    setup_config_env
    write_config "./.honeybadger.conf" <<'EOF'
SERVER_URL=http://working-directory/
EOF
    write_config "$CONFIG_WORKDIR/named.conf" <<'EOF'
SERVER_URL=http://named/
EOF

    export HONEYBADGER_CONFIG="$CONFIG_WORKDIR/named.conf"
    load_server_config > /dev/null

    assert_equals "http://named/" "$SERVER_URL" "the environment names the file"

    teardown_config_env
}

test_an_argument_beats_honeybadger_config() {
    setup_config_env
    write_config "$CONFIG_WORKDIR/from-env.conf" <<'EOF'
SERVER_URL=http://from-env-file/
EOF
    write_config "$CONFIG_WORKDIR/from-arg.conf" <<'EOF'
SERVER_URL=http://from-arg-file/
EOF

    export HONEYBADGER_CONFIG="$CONFIG_WORKDIR/from-env.conf"
    load_server_config "$CONFIG_WORKDIR/from-arg.conf" > /dev/null

    assert_equals "http://from-arg-file/" "$SERVER_URL" "the argument wins"

    teardown_config_env
}

test_a_named_file_that_is_missing_is_an_error() {
    # Falling back to the search order would submit somewhere the caller did
    # not ask for, which is the whole problem this avoids.
    setup_config_env
    write_config "./.honeybadger.conf" <<'EOF'
SERVER_URL=http://working-directory/
EOF

    local output status
    output=$(load_server_config "$CONFIG_WORKDIR/absent.conf" 2>&1)
    status=$?

    assert_failure "naming a file that is not there" "$status"
    assert_contains "$output" "absent.conf" "the missing path is named"

    teardown_config_env
}

test_the_search_order_still_starts_at_the_working_directory() {
    setup_config_env
    write_config "./.honeybadger.conf" <<'EOF'
SERVER_URL=http://working-directory/
EOF
    write_config "$HOME/.honeybadger.conf" <<'EOF'
SERVER_URL=http://home/
EOF

    load_server_config > /dev/null

    assert_equals "http://working-directory/" "$SERVER_URL" "the working directory is searched first"

    teardown_config_env
}

# ------------------------------------------------------------- reporting

test_the_loaded_file_is_reported() {
    setup_config_env
    write_config "$CONFIG_WORKDIR/c.conf" <<'EOF'
SERVER_URL=http://from-file/
EOF

    local output
    output=$(load_server_config "$CONFIG_WORKDIR/c.conf" 2>&1)

    assert_contains "$output" "c.conf" "the file that was used is named"

    teardown_config_env
}

test_environment_overrides_are_reported() {
    setup_config_env
    write_config "$CONFIG_WORKDIR/c.conf" <<'EOF'
SERVER_URL=http://from-file/
EOF

    SERVER_URL="http://from-environment/"
    DRY_RUN="true"
    local output
    output=$(load_server_config "$CONFIG_WORKDIR/c.conf" 2>&1)

    assert_contains "$output" "SERVER_URL" "the overridden setting is named"
    assert_contains "$output" "DRY_RUN" "and so is the other one"

    teardown_config_env
}

test_no_config_file_is_reported() {
    setup_config_env

    local output
    output=$(load_server_config 2>&1)
    assert_contains "$output" "No configuration file found" "the absence is reported"

    # The capture above ran in a subshell, so the settings it resolved did not
    # reach this one. Resolve again in the current shell to inspect them.
    load_server_config > /dev/null
    assert_equals "http://localhost:7123/" "$SERVER_URL" "and the default is used"

    teardown_config_env
}

run_tests "$@"
