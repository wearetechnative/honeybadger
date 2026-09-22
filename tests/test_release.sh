#!/usr/bin/env bash
# Cover release.sh against a throwaway git repository.
#
# The script derives its repo root from its own location, so each test copies
# it into a fresh repo under $TMPDIR and runs it there. Nothing here touches the
# honeybadger checkout, and no test can leave a tag or a commit behind.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
source "$TESTS_DIR/lib.sh"

RELEASE_SH="$REPO_ROOT/release.sh"

# A repo holding just the two files release.sh writes, committed so the working
# tree starts clean.
make_repo() {
    local version="${1:-0.6.0}" changelog_body="${2:-default}" dir
    dir="$(mktemp -d)"

    cp "$RELEASE_SH" "$dir/release.sh"
    printf '%s\n' "$version" > "$dir/VERSION-honeybadger"

    if [[ "$changelog_body" == "default" ]]; then
        cat > "$dir/CHANGELOG.md" <<'EOF'
# Changelog HoneyBadger

## NEXT VERSION

### Added

- **Something** - it does a thing

## 0.6.0 - Enhanced ISO27001 Compliance Reporting (March 2026)

### Added

- an older entry
EOF
    else
        printf '%s\n' "$changelog_body" > "$dir/CHANGELOG.md"
    fi

    git -C "$dir" init -q
    git -C "$dir" config user.email "tests@honeybadger.invalid"
    git -C "$dir" config user.name "honeybadger tests"
    git -C "$dir" add -A
    git -C "$dir" commit -q -m "initial"

    printf '%s' "$dir"
}

# Run release.sh inside $1 with a fixed date, capturing output and status.
# Sets RELEASE_OUTPUT and RELEASE_STATUS.
run_release() {
    local dir="$1"; shift
    RELEASE_OUTPUT="$(HB_RELEASE_DATE="September 2026" "$dir/release.sh" "$@" 2>&1)"
    RELEASE_STATUS=$?
}

test_rejects_a_version_that_is_not_semver() {
    local dir; dir="$(make_repo)"
    run_release "$dir" "0.7"
    assert_failure "a two-part version is refused" "$RELEASE_STATUS"
    assert_contains "$RELEASE_OUTPUT" "not a X.Y.Z version"
    rm -rf "$dir"
}

test_rejects_a_version_that_does_not_move_forward() {
    local dir; dir="$(make_repo "0.6.0")"
    run_release "$dir" "0.5.0"
    assert_failure "an older version is refused" "$RELEASE_STATUS"
    assert_contains "$RELEASE_OUTPUT" "does not come after the current 0.6.0"

    run_release "$dir" "0.6.0"
    assert_failure "the current version is refused" "$RELEASE_STATUS"
    rm -rf "$dir"
}

test_rejects_a_changelog_without_an_open_section() {
    local dir
    dir="$(make_repo "0.6.0" "# Changelog HoneyBadger

## 0.6.0 - Something (March 2026)

- an entry")"
    run_release "$dir" "0.7.0"
    assert_failure "a missing NEXT VERSION is refused" "$RELEASE_STATUS"
    assert_contains "$RELEASE_OUTPUT" "is missing from CHANGELOG.md"
    rm -rf "$dir"
}

test_rejects_an_empty_open_section() {
    local dir
    dir="$(make_repo "0.6.0" "# Changelog HoneyBadger

## NEXT VERSION

## 0.6.0 - Something (March 2026)

- an entry")"
    run_release "$dir" "0.7.0"
    assert_failure "an empty NEXT VERSION is refused" "$RELEASE_STATUS"
    assert_contains "$RELEASE_OUTPUT" "is empty"
    rm -rf "$dir"
}

test_rejects_a_dirty_working_tree() {
    local dir; dir="$(make_repo)"
    echo "stray" > "$dir/untracked.txt"
    run_release "$dir" "0.7.0"
    assert_failure "an unclean tree is refused" "$RELEASE_STATUS"
    assert_contains "$RELEASE_OUTPUT" "uncommitted changes"
    rm -rf "$dir"
}

test_rejects_a_tag_that_already_exists() {
    local dir; dir="$(make_repo)"
    git -C "$dir" tag "v0.7.0"
    run_release "$dir" "0.7.0"
    assert_failure "an existing tag is refused" "$RELEASE_STATUS"
    assert_contains "$RELEASE_OUTPUT" "tag v0.7.0 already exists"
    rm -rf "$dir"
}

test_a_dry_run_writes_nothing() {
    local dir; dir="$(make_repo)"
    run_release "$dir" --dry-run "0.7.0" "Windows tar submission"
    assert_success "a dry run succeeds" "$RELEASE_STATUS"
    assert_contains "$RELEASE_OUTPUT" "0.6.0 -> 0.7.0"
    assert_contains "$RELEASE_OUTPUT" "## 0.7.0 - Windows tar submission (September 2026)"
    assert_contains "$RELEASE_OUTPUT" "nothing was written"

    assert_equals "0.6.0" "$(tr -d '[:space:]' < "$dir/VERSION-honeybadger")" \
        "the version file is untouched"
    assert_contains "$(cat "$dir/CHANGELOG.md")" "## NEXT VERSION" \
        "the open heading survives a dry run"
    assert_equals "" "$(git -C "$dir" tag)" "no tag is written"
    rm -rf "$dir"
}

test_a_dry_run_works_on_a_dirty_tree() {
    local dir; dir="$(make_repo)"
    echo "work in progress" >> "$dir/CHANGELOG.md"
    run_release "$dir" --dry-run "0.7.0" "Still drafting"
    assert_success "a dry run does not demand a clean tree" "$RELEASE_STATUS"
    rm -rf "$dir"
}

test_a_release_bumps_rewrites_commits_and_tags() {
    local dir; dir="$(make_repo)"
    run_release "$dir" "0.7.0" "Windows tar submission"
    assert_success "the release succeeds" "$RELEASE_STATUS"

    assert_equals "0.7.0" "$(tr -d '[:space:]' < "$dir/VERSION-honeybadger")" \
        "the version file is bumped"

    local changelog; changelog="$(cat "$dir/CHANGELOG.md")"
    assert_contains "$changelog" "## 0.7.0 - Windows tar submission (September 2026)"
    local remaining
    remaining="$(grep -c '^## NEXT VERSION$' "$dir/CHANGELOG.md" || true)"
    assert_equals "0" "$remaining" "the open heading is consumed"
    assert_contains "$changelog" "- **Something** - it does a thing" \
        "the entries below the heading are kept"
    assert_contains "$changelog" "## 0.6.0 - Enhanced ISO27001 Compliance Reporting (March 2026)" \
        "older releases are untouched"

    assert_equals "Release 0.7.0" "$(git -C "$dir" log -1 --format=%s)" \
        "the release commit subject"
    assert_equals "v0.7.0" "$(git -C "$dir" tag)" "the tag is written"
    assert_equals "$(git -C "$dir" rev-parse HEAD)" \
        "$(git -C "$dir" rev-list -1 v0.7.0)" "the tag sits on the release commit"
    assert_equals "" "$(git -C "$dir" status --porcelain)" \
        "the release leaves a clean tree"
    rm -rf "$dir"
}

test_a_release_commits_only_the_two_version_files() {
    local dir; dir="$(make_repo)"
    run_release "$dir" "0.7.0" "Windows tar submission"
    assert_success "the release succeeds" "$RELEASE_STATUS"
    assert_equals "CHANGELOG.md
VERSION-honeybadger" "$(git -C "$dir" show --name-only --format= HEAD | sort)" \
        "the commit touches nothing else"
    rm -rf "$dir"
}

test_a_title_with_punctuation_survives() {
    local dir; dir="$(make_repo)"
    run_release "$dir" "0.7.0" "Tar & submit: input/output"
    assert_success "the release succeeds" "$RELEASE_STATUS"
    assert_contains "$(cat "$dir/CHANGELOG.md")" \
        "## 0.7.0 - Tar & submit: input/output (September 2026)"
    rm -rf "$dir"
}

test_a_release_without_a_title_still_carries_the_date() {
    local dir; dir="$(make_repo)"
    run_release "$dir" "0.7.0"
    assert_success "the release succeeds" "$RELEASE_STATUS"
    assert_contains "$(cat "$dir/CHANGELOG.md")" "## 0.7.0 (September 2026)"
    rm -rf "$dir"
}

run_tests "$@"
