#!/usr/bin/env bash
# Cut a honeybadger release: bump the version, close the changelog's open
# section, commit and tag.
#
#   ./release.sh 0.7.0 "Windows tar submission"
#   ./release.sh --dry-run 0.7.0 "Windows tar submission"
#
# The version lives in three places that have drifted apart before, so this
# script is the only thing that writes them and it writes them together:
#
#   VERSION-honeybadger   read by RUNME.sh, lib/_library and AUDIT.ps1, and
#                         recorded in every asset-inventory.json
#   CHANGELOG.md          the "## NEXT VERSION" heading becomes the release
#   git tag vX.Y.Z        annotated, on the release commit
#
# Nothing is pushed. The push is a separate, deliberate step, printed at the
# end - a tag that reaches the remote cannot be rewritten quietly.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="$REPO_ROOT/VERSION-honeybadger"
CHANGELOG="$REPO_ROOT/CHANGELOG.md"
OPEN_HEADING="## NEXT VERSION"

die() {
    echo "release: $1" >&2
    exit 1
}

usage() {
    sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 2
}

# X.Y.Z only. A release that cannot be compared against its predecessor cannot
# be checked for going backwards, and pre-release suffixes have never been used
# here.
is_semver() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# True when $1 is strictly newer than $2.
is_newer_than() {
    local candidate="$1" current="$2"
    [[ "$candidate" != "$current" ]] &&
        [[ "$(printf '%s\n%s\n' "$current" "$candidate" | sort -V | tail -1)" == "$candidate" ]]
}

# "September 2026", independent of the operator's locale. Overridable so the
# tests do not have to be rerun in a different month.
release_date() {
    if [[ -n "${HB_RELEASE_DATE:-}" ]]; then
        printf '%s' "$HB_RELEASE_DATE"
    else
        LC_ALL=C date +'%B %Y'
    fi
}

changelog_heading() {
    local version="$1" title="$2" date
    date="$(release_date)"
    if [[ -n "$title" ]]; then
        printf '## %s - %s (%s)' "$version" "$title" "$date"
    else
        printf '## %s (%s)' "$version" "$date"
    fi
}

# The open section has to carry something, or the release records nothing. Read
# from the heading to the next "## " or to the end of the file.
open_section_is_empty() {
    local file="$1"
    awk -v heading="$OPEN_HEADING" '
        $0 == heading { inside = 1; next }
        inside && /^## / { exit }
        inside && NF { found = 1; exit }
        END { exit(found ? 1 : 0) }
    ' "$file"
}

# Replace only the first occurrence, with awk rather than sed so a title
# containing & or / needs no escaping.
rewrite_heading() {
    local file="$1" heading="$2" tmp
    tmp="$(mktemp)"
    awk -v old="$OPEN_HEADING" -v new="$heading" '
        !done && $0 == old { print new; done = 1; next }
        { print }
    ' "$file" > "$tmp"
    cat "$tmp" > "$file"
    rm -f "$tmp"
}

main() {
    local dry_run=false version="" title=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) dry_run=true; shift ;;
            -h|--help) usage ;;
            -*) die "unknown option: $1" ;;
            *)
                if [[ -z "$version" ]]; then
                    version="$1"
                elif [[ -z "$title" ]]; then
                    title="$1"
                else
                    die "unexpected argument: $1 (quote the title as one word)"
                fi
                shift
                ;;
        esac
    done

    [[ -n "$version" ]] || usage
    is_semver "$version" || die "'$version' is not a X.Y.Z version"

    [[ -f "$VERSION_FILE" ]] || die "$VERSION_FILE is missing"
    [[ -f "$CHANGELOG" ]] || die "$CHANGELOG is missing"

    local current
    current="$(tr -d '[:space:]' < "$VERSION_FILE")"
    is_semver "$current" ||
        die "$VERSION_FILE holds '$current', which is not a X.Y.Z version"
    is_newer_than "$version" "$current" ||
        die "$version does not come after the current $current"

    local tag="v$version"
    if git -C "$REPO_ROOT" rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
        die "tag $tag already exists"
    fi

    grep -qxF "$OPEN_HEADING" "$CHANGELOG" ||
        die "$OPEN_HEADING is missing from CHANGELOG.md - write the entries first"
    if open_section_is_empty "$CHANGELOG"; then
        die "$OPEN_HEADING is empty - write the entries first"
    fi

    if ! $dry_run && [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
        die "the working tree has uncommitted changes - commit or stash them first"
    fi

    local heading
    heading="$(changelog_heading "$version" "$title")"

    echo
    echo "  VERSION-honeybadger : $current -> $version"
    echo "  CHANGELOG.md        : $OPEN_HEADING"
    echo "                     -> $heading"
    echo "  git commit          : \"Release $version\""
    echo "  git tag             : $tag"
    echo

    if $dry_run; then
        echo "  dry run - nothing was written"
        return 0
    fi

    printf '%s\n' "$version" > "$VERSION_FILE"
    rewrite_heading "$CHANGELOG" "$heading"

    git -C "$REPO_ROOT" add -- VERSION-honeybadger CHANGELOG.md
    git -C "$REPO_ROOT" commit -q -m "Release $version"
    git -C "$REPO_ROOT" tag -a "$tag" -m "Release $version"

    echo "  Released $version. Push it with:"
    echo
    echo "    git push && git push origin $tag"
    echo
}

# Sourcing this file gives a test the functions above without releasing
# anything.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
