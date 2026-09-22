#!/usr/bin/env bash
# Cut a honeybadger release: bump the version, close the changelog's open
# section, commit, tag and optionally push.
#
#   ./release.sh                                    interactive
#   ./release.sh 0.7.0 "Windows tar submission"     scripted
#   ./release.sh --dry-run 0.7.0 "Windows tar"      show, write nothing
#
# The version lives in three places that have drifted apart before, so this
# script is the only thing that writes them and it writes them together:
#
#   VERSION-honeybadger   read by RUNME.sh, lib/_library and AUDIT.ps1, and
#                         recorded in every asset-inventory.json
#   CHANGELOG.md          the "## NEXT VERSION" heading becomes the release
#   git tag vX.Y.Z        annotated, on the release commit
#
# Run without arguments it walks you through the release: the bump, any
# OpenSpec changes still waiting to be archived, the changelog, and the push.
# Run with a version it does the same work without asking, and never pushes -
# that form is what the tests drive.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="$REPO_ROOT/VERSION-honeybadger"
CHANGELOG="$REPO_ROOT/CHANGELOG.md"
OPEN_HEADING="## NEXT VERSION"

# Colour only when a terminal is reading. A pipe gets clean text, which is what
# keeps the tests asserting on messages rather than on escape codes.
if [[ -t 1 ]]; then
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
    BLUE=$'\033[0;34m'; NC=$'\033[0m'
else
    RED=""; GREEN=""; YELLOW=""; BLUE=""; NC=""
fi

print_info()    { echo "${BLUE}i${NC} $1"; }
print_success() { echo "${GREEN}✓${NC} $1"; }
print_warning() { echo "${YELLOW}!${NC} $1"; }
print_error()   { echo "${RED}✗${NC} $1" >&2; }

die() {
    print_error "release: $1"
    exit 1
}

# read that refuses to treat a closed stdin as an answer. Without this an
# unattended run would take the empty string for every prompt and fall through
# to whatever that happens to mean.
ask() {
    local __var="$1" prompt="$2" reply
    if ! read -r -p "$prompt" reply; then
        die "no answer given (stdin closed) - run this from a terminal"
    fi
    printf -v "$__var" '%s' "$reply"
}

usage() {
    sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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

# Everything under the released heading, for the annotated tag's message.
section_body() {
    local file="$1" heading="$2"
    awk -v want="$heading" '
        $0 == want { inside = 1; next }
        inside && /^## / { exit }
        inside { print }
    ' "$file" | sed -e '/./,$!d' | awk 'NF {blank = 0; print; next} {blank++; if (blank < 2) print}'
}

# Add entries to the open section, creating it when the changelog has none.
# Keeps a single code path for the heading rewrite below.
insert_entries() {
    local file="$1" entries="$2" tmp
    tmp="$(mktemp)"
    if grep -qxF "$OPEN_HEADING" "$file"; then
        awk -v heading="$OPEN_HEADING" -v entries="$entries" '
            !done && $0 == heading { print; print ""; print entries; done = 1; next }
            { print }
        ' "$file" > "$tmp"
    else
        # Below the document title, above the newest release.
        awk -v heading="$OPEN_HEADING" -v entries="$entries" '
            NR == 1 { print; print ""; print heading; print ""; print entries; next }
            { print }
        ' "$file" > "$tmp"
    fi
    cat "$tmp" > "$file"
    rm -f "$tmp"
}

# Offer to archive the OpenSpec changes that report themselves complete. They
# are archived one at a time: the whole point of the archive step is that each
# change moves on its own, and a loop that stops halfway leaves a readable state.
archive_openspec_changes() {
    command -v openspec >/dev/null 2>&1 || {
        print_warning "OpenSpec CLI not found, skipping the archive check"
        return 0
    }

    local completed
    completed="$(cd "$REPO_ROOT" && openspec list 2>/dev/null |
        grep "✓ Complete" | awk '{print $1}' || true)"

    if [[ -z "$completed" ]]; then
        print_success "No completed OpenSpec changes to archive"
        return 0
    fi

    print_warning "These OpenSpec changes report themselves complete:"
    echo
    (cd "$REPO_ROOT" && openspec list 2>/dev/null | grep "✓ Complete") || true
    echo
    local answer
    ask answer "Archive them before releasing? (y/n): "
    if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
        print_warning "Leaving them open"
        return 0
    fi

    local change
    while read -r change; do
        [[ -n "$change" ]] || continue
        print_info "Archiving $change..."
        if (cd "$REPO_ROOT" && openspec archive "$change" --yes >/dev/null 2>&1); then
            print_success "Archived $change"
        else
            print_warning "Could not archive $change - archive it by hand"
        fi
    done <<< "$completed"

    if [[ -n "$(git -C "$REPO_ROOT" status --porcelain -- openspec/)" ]]; then
        git -C "$REPO_ROOT" add -- openspec/
        git -C "$REPO_ROOT" commit -q -m "Archive completed OpenSpec changes before the release"
        print_success "Archived changes committed"
    fi
}

# Ask which bump this is, computed from the current version so no one types a
# version by hand - a typo there is a tag that cannot be taken back.
choose_version() {
    local current="$1" major minor patch choice
    IFS='.' read -r major minor patch <<< "$current"

    echo >&2
    echo "Current version: $current" >&2
    echo >&2
    echo "Select release type:" >&2
    echo "  1) Patch   ($major.$minor.$((patch + 1))) - fixes only" >&2
    echo "  2) Minor   ($major.$((minor + 1)).0) - new features, backwards compatible" >&2
    echo "  3) Major   ($((major + 1)).0.0) - breaking changes" >&2
    echo >&2
    ask choice "Enter choice (1-3): "

    case "$choice" in
        1) printf '%s.%s.%s' "$major" "$minor" "$((patch + 1))" ;;
        2) printf '%s.%s.0' "$major" "$((minor + 1))" ;;
        3) printf '%s.0.0' "$((major + 1))" ;;
        *) die "invalid choice: $choice" ;;
    esac
}

main() {
    local dry_run=false version="" title="" interactive=false

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

    [[ -f "$VERSION_FILE" ]] || die "$VERSION_FILE is missing"
    [[ -f "$CHANGELOG" ]] || die "$CHANGELOG is missing"
    git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1 ||
        die "$REPO_ROOT is not a git repository"

    # No version on the command line means walk the operator through it.
    [[ -z "$version" ]] && interactive=true

    local current
    current="$(tr -d '[:space:]' < "$VERSION_FILE")"
    is_semver "$current" ||
        die "$VERSION_FILE holds '$current', which is not a X.Y.Z version"

    # The clean-tree check comes before anything that writes, so a refusal
    # never leaves half a release behind.
    if ! $dry_run && [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
        git -C "$REPO_ROOT" status --short
        die "the working tree has uncommitted changes - commit or stash them first"
    fi

    if $interactive; then
        print_info "Checking that the remote is reachable..."
        git -C "$REPO_ROOT" ls-remote --exit-code origin >/dev/null 2>&1 ||
            die "cannot reach origin - check your network before starting a release"
        print_success "origin is reachable"

        version="$(choose_version "$current")"
    fi

    is_semver "$version" || die "'$version' is not a X.Y.Z version"
    is_newer_than "$version" "$current" ||
        die "$version does not come after the current $current"

    local tag="v$version"
    if git -C "$REPO_ROOT" rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
        die "tag $tag already exists"
    fi
    $interactive && print_success "$tag is available"

    if $interactive; then
        echo
        archive_openspec_changes
        echo
    fi

    # Stacked open sections would each become the same heading, so refuse and
    # let the author merge them first.
    local open_count
    open_count="$(grep -cxF "$OPEN_HEADING" "$CHANGELOG" || true)"
    if [[ "$open_count" -gt 1 ]]; then
        grep -nxF "$OPEN_HEADING" "$CHANGELOG" >&2
        die "found $open_count '$OPEN_HEADING' headings - merge them into one first"
    fi

    if $interactive; then
        echo "CHANGELOG.md"
        echo "  1) The entries are already written under '$OPEN_HEADING'"
        echo "  2) Enter them now"
        echo
        local changelog_choice
        ask changelog_choice "Enter choice (1-2): "
        if [[ "$changelog_choice" == "2" ]]; then
            echo
            print_info "One entry per line. End with Ctrl-D, or a line holding just a dot:"
            local entries="" line
            while IFS= read -r line; do
                [[ "$line" == "." ]] && break
                entries+="$line"$'\n'
            done
            entries="${entries%$'\n'}"
            [[ -n "$entries" ]] || die "no changelog entries given"
            insert_entries "$CHANGELOG" "$entries"
            print_success "Entries added under $OPEN_HEADING"
        elif [[ "$changelog_choice" != "1" ]]; then
            die "invalid choice: $changelog_choice"
        fi
    fi

    grep -qxF "$OPEN_HEADING" "$CHANGELOG" ||
        die "$OPEN_HEADING is missing from CHANGELOG.md - write the entries first"
    if open_section_is_empty "$CHANGELOG"; then
        die "$OPEN_HEADING is empty - write the entries first"
    fi

    if $interactive; then
        echo
        print_info "The heading reads '## $version - <title> ($(release_date))'."
        ask title "Release title (blank for none): "
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

    if $interactive; then
        print_info "Changes to be committed:"
        echo
        git -C "$REPO_ROOT" --no-pager diff -- VERSION-honeybadger CHANGELOG.md
        echo
        local confirm
        ask confirm "Commit and tag these changes? (y/n): "
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            git -C "$REPO_ROOT" checkout -- VERSION-honeybadger CHANGELOG.md
            print_warning "Rolled back. Nothing was committed or tagged."
            return 0
        fi
    fi

    git -C "$REPO_ROOT" add -- VERSION-honeybadger CHANGELOG.md
    git -C "$REPO_ROOT" commit -q -m "Release $version"

    local tag_message
    tag_message="Release $version

$(section_body "$CHANGELOG" "$heading")"
    git -C "$REPO_ROOT" tag -a "$tag" -m "$tag_message"

    print_success "Released $version"
    echo "  commit: $(git -C "$REPO_ROOT" log -1 --pretty=format:'%h - %s')"
    echo "  tag:    $tag"
    echo

    local branch
    branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"

    # Scripted runs never push. A tag that reaches the remote cannot be
    # rewritten quietly, so that step is always someone saying yes.
    if ! $interactive; then
        echo "  Push it with:"
        echo
        echo "    git push origin $branch && git push origin $tag"
        echo
        return 0
    fi

    local confirm_push
    ask confirm_push "Push $branch and $tag to origin? (y/n): "
    if [[ "$confirm_push" != "y" && "$confirm_push" != "Y" ]]; then
        print_warning "Not pushed. Push it later with:"
        echo
        echo "    git push origin $branch && git push origin $tag"
        echo
        return 0
    fi

    git -C "$REPO_ROOT" push origin "$branch"
    git -C "$REPO_ROOT" push origin "$tag"
    print_success "Pushed $branch and $tag to origin"
}

# Sourcing this file gives a test the functions above without releasing
# anything.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
