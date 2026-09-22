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
    local version="${1:-0.6.0}" changelog_body="${2:-default}" parent dir
    parent="$(mktemp -d)"
    dir="$parent/work"
    mkdir -p "$dir"

    git init -q --bare "$parent/origin.git"

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
    git -C "$dir" remote add origin "$parent/origin.git"
    git -C "$dir" push -q -u origin HEAD

    printf '%s' "$dir"
}

# Remove the repository and the bare origin beside it.
cleanup_repo() {
    rm -rf "$(dirname "$1")"
}

# The bare origin make_repo pushed to.
origin_of() {
    printf '%s' "$(dirname "$1")/origin.git"
}

# Drive the interactive form: answers arrive on stdin, one prompt per line.
# Sets RELEASE_OUTPUT and RELEASE_STATUS.
run_release_interactive() {
    local dir="$1" answers="$2"
    RELEASE_OUTPUT="$(printf '%s\n' "$answers" |
        HB_RELEASE_DATE="September 2026" "$dir/release.sh" 2>&1)"
    RELEASE_STATUS=$?
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
    cleanup_repo "$dir"
}

test_rejects_a_version_that_does_not_move_forward() {
    local dir; dir="$(make_repo "0.6.0")"
    run_release "$dir" "0.5.0"
    assert_failure "an older version is refused" "$RELEASE_STATUS"
    assert_contains "$RELEASE_OUTPUT" "does not come after the current 0.6.0"

    run_release "$dir" "0.6.0"
    assert_failure "the current version is refused" "$RELEASE_STATUS"
    cleanup_repo "$dir"
}

test_rejects_a_changelog_without_an_open_section() {
    local dir
    dir="$(make_repo "0.6.0" "# Changelog HoneyBadger

## 0.6.0 - Something (March 2026)

- an entry")"
    run_release "$dir" "0.7.0"
    assert_failure "a missing NEXT VERSION is refused" "$RELEASE_STATUS"
    assert_contains "$RELEASE_OUTPUT" "is missing from CHANGELOG.md"
    cleanup_repo "$dir"
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
    cleanup_repo "$dir"
}

test_rejects_a_dirty_working_tree() {
    local dir; dir="$(make_repo)"
    echo "stray" > "$dir/untracked.txt"
    run_release "$dir" "0.7.0"
    assert_failure "an unclean tree is refused" "$RELEASE_STATUS"
    assert_contains "$RELEASE_OUTPUT" "uncommitted changes"
    cleanup_repo "$dir"
}

test_rejects_a_tag_that_already_exists() {
    local dir; dir="$(make_repo)"
    git -C "$dir" tag "v0.7.0"
    run_release "$dir" "0.7.0"
    assert_failure "an existing tag is refused" "$RELEASE_STATUS"
    assert_contains "$RELEASE_OUTPUT" "tag v0.7.0 already exists"
    cleanup_repo "$dir"
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
    cleanup_repo "$dir"
}

test_a_dry_run_works_on_a_dirty_tree() {
    local dir; dir="$(make_repo)"
    echo "work in progress" >> "$dir/CHANGELOG.md"
    run_release "$dir" --dry-run "0.7.0" "Still drafting"
    assert_success "a dry run does not demand a clean tree" "$RELEASE_STATUS"
    cleanup_repo "$dir"
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
    cleanup_repo "$dir"
}

test_a_release_commits_only_the_two_version_files() {
    local dir; dir="$(make_repo)"
    run_release "$dir" "0.7.0" "Windows tar submission"
    assert_success "the release succeeds" "$RELEASE_STATUS"
    assert_equals "CHANGELOG.md
VERSION-honeybadger" "$(git -C "$dir" show --name-only --format= HEAD | sort)" \
        "the commit touches nothing else"
    cleanup_repo "$dir"
}

test_a_title_with_punctuation_survives() {
    local dir; dir="$(make_repo)"
    run_release "$dir" "0.7.0" "Tar & submit: input/output"
    assert_success "the release succeeds" "$RELEASE_STATUS"
    assert_contains "$(cat "$dir/CHANGELOG.md")" \
        "## 0.7.0 - Tar & submit: input/output (September 2026)"
    cleanup_repo "$dir"
}

test_a_release_without_a_title_still_carries_the_date() {
    local dir; dir="$(make_repo)"
    run_release "$dir" "0.7.0"
    assert_success "the release succeeds" "$RELEASE_STATUS"
    assert_contains "$(cat "$dir/CHANGELOG.md")" "## 0.7.0 (September 2026)"
    cleanup_repo "$dir"
}

test_the_bump_menu_computes_each_release_type() {
    local dir; dir="$(make_repo "0.6.4")"

    run_release_interactive "$dir" "1
1
A patch
n
n"
    assert_success "a patch release succeeds" "$RELEASE_STATUS"
    assert_contains "$RELEASE_OUTPUT" "0.6.4 -> 0.6.5" "choice 1 bumps the patch"
    cleanup_repo "$dir"

    dir="$(make_repo "0.6.4")"
    run_release_interactive "$dir" "2
1
A minor
n
n"
    assert_contains "$RELEASE_OUTPUT" "0.6.4 -> 0.7.0" \
        "choice 2 bumps the minor and zeroes the patch"
    cleanup_repo "$dir"

    dir="$(make_repo "0.6.4")"
    run_release_interactive "$dir" "3
1
A major
n
n"
    assert_contains "$RELEASE_OUTPUT" "0.6.4 -> 1.0.0" \
        "choice 3 bumps the major and zeroes the rest"
    cleanup_repo "$dir"
}

test_an_interactive_release_commits_tags_and_declines_the_push() {
    local dir; dir="$(make_repo "0.6.0")"
    run_release_interactive "$dir" "2
1
Windows tar submission
y
n"
    assert_success "the release succeeds" "$RELEASE_STATUS"
    assert_contains "$RELEASE_OUTPUT" "origin is reachable"
    assert_contains "$RELEASE_OUTPUT" "v0.7.0 is available"

    assert_contains "$(cat "$dir/CHANGELOG.md")" \
        "## 0.7.0 - Windows tar submission (September 2026)"
    assert_equals "Release 0.7.0" "$(git -C "$dir" log -1 --format=%s)"
    assert_equals "v0.7.0" "$(git -C "$dir" tag)"

    assert_contains "$RELEASE_OUTPUT" "Not pushed"
    assert_equals "" "$(git -C "$(origin_of "$dir")" tag)" \
        "declining the push leaves the origin without the tag"
    cleanup_repo "$dir"
}

test_an_interactive_release_pushes_the_branch_and_the_tag() {
    local dir; dir="$(make_repo "0.6.0")"
    run_release_interactive "$dir" "2
1
Windows tar submission
y
y"
    assert_success "the release succeeds" "$RELEASE_STATUS"
    assert_contains "$RELEASE_OUTPUT" "Pushed"

    local origin; origin="$(origin_of "$dir")"
    assert_equals "v0.7.0" "$(git -C "$origin" tag)" "the tag reaches the origin"
    assert_equals "$(git -C "$dir" rev-parse HEAD)" \
        "$(git -C "$origin" rev-parse HEAD)" "the release commit reaches the origin"
    cleanup_repo "$dir"
}

test_declining_the_commit_rolls_everything_back() {
    local dir; dir="$(make_repo "0.6.0")"
    local before; before="$(git -C "$dir" rev-parse HEAD)"

    run_release_interactive "$dir" "2
1
Windows tar submission
n"
    assert_success "declining is not an error" "$RELEASE_STATUS"
    assert_contains "$RELEASE_OUTPUT" "Rolled back"

    assert_equals "0.6.0" "$(tr -d '[:space:]' < "$dir/VERSION-honeybadger")" \
        "the version file is restored"
    assert_contains "$(cat "$dir/CHANGELOG.md")" "## NEXT VERSION" \
        "the open heading is restored"
    assert_equals "$before" "$(git -C "$dir" rev-parse HEAD)" "no commit was made"
    assert_equals "" "$(git -C "$dir" tag)" "no tag was written"
    assert_equals "" "$(git -C "$dir" status --porcelain)" "the tree is clean again"
    cleanup_repo "$dir"
}

test_entries_typed_at_the_prompt_reach_the_changelog() {
    local dir
    dir="$(make_repo "0.6.0" "# Changelog HoneyBadger

## NEXT VERSION

## 0.6.0 - Something (March 2026)

- an older entry")"

    run_release_interactive "$dir" "2
2
- **Typed entry** - written at the prompt
- a second line
.
Typed release
y
n"
    assert_success "the release succeeds" "$RELEASE_STATUS"

    local changelog; changelog="$(cat "$dir/CHANGELOG.md")"
    assert_contains "$changelog" "- **Typed entry** - written at the prompt"
    assert_contains "$changelog" "- a second line"
    assert_contains "$changelog" "## 0.7.0 - Typed release (September 2026)"
    assert_contains "$changelog" "## 0.6.0 - Something (March 2026)" \
        "the older release survives"
    cleanup_repo "$dir"
}

test_an_empty_section_is_refused_even_when_entries_were_offered() {
    local dir
    dir="$(make_repo "0.6.0" "# Changelog HoneyBadger

## NEXT VERSION

## 0.6.0 - Something (March 2026)

- an older entry")"
    run_release_interactive "$dir" "2
1"
    assert_failure "choosing 'already written' over an empty section is refused" "$RELEASE_STATUS"
    assert_contains "$RELEASE_OUTPUT" "is empty"
    cleanup_repo "$dir"
}

test_stacked_open_sections_are_refused() {
    local dir
    dir="$(make_repo "0.6.0" "# Changelog HoneyBadger

## NEXT VERSION

- one thing

## NEXT VERSION

- another thing

## 0.6.0 - Something (March 2026)

- an older entry")"
    run_release "$dir" "0.7.0"
    assert_failure "two open headings are refused" "$RELEASE_STATUS"
    assert_contains "$RELEASE_OUTPUT" "found 2"
    assert_contains "$RELEASE_OUTPUT" "merge them into one first"
    cleanup_repo "$dir"
}

test_the_tag_message_carries_the_changelog_entries() {
    local dir; dir="$(make_repo)"
    run_release "$dir" "0.7.0" "Windows tar submission"
    assert_success "the release succeeds" "$RELEASE_STATUS"

    local message; message="$(git -C "$dir" tag -l --format='%(contents)' v0.7.0)"
    assert_contains "$message" "Release 0.7.0"
    assert_contains "$message" "- **Something** - it does a thing" \
        "the released entries travel in the tag"
    cleanup_repo "$dir"
}

test_a_closed_stdin_is_not_an_answer() {
    local dir; dir="$(make_repo)"
    RELEASE_OUTPUT="$(HB_RELEASE_DATE="September 2026" "$dir/release.sh" < /dev/null 2>&1)"
    RELEASE_STATUS=$?
    assert_failure "an unattended interactive run is refused" "$RELEASE_STATUS"
    assert_contains "$RELEASE_OUTPUT" "no answer given"
    cleanup_repo "$dir"
}

run_tests "$@"
