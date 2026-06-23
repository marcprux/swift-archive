#!/usr/bin/env bash
#
# swift-release.sh — tag and release swift-libarchive in sync with an upstream release.
#
# This automates the workflow documented in README-SWIFT.md
# ("Synchronizing Releases with Upstream"):
#
#   1. Fetch the upstream libarchive tags.
#   2. Merge the chosen upstream release tag into the `swift` overlay branch
#      (the overlay is purely additive, so this is conflict-free).
#   3. Build and test the Swift package.
#   4. Re-tag the overlay commit with the same vX.Y.Z version, overriding the
#      upstream-mirrored tag of that name, and push it.
#   5. Publish the GitHub release.
#
# The release tag always ends up pointing at a commit that contains
# Package.swift, which is what makes it resolvable by SwiftPM from this repo.
#
# Usage:
#   Scripts/swift-release.sh [VERSION] [options]
#
#   VERSION   Upstream release to mirror, e.g. "3.8.7" or "v3.8.7".
#             If omitted, defaults to the most recent upstream release tag.
#
# Options:
#   -y, --yes        Do not prompt before the (force) tag push and release.
#       --dry-run    Print the plan without merging, tagging, pushing, or releasing.
#       --no-test    Skip `swift build` / `swift test`.
#       --no-release Create and push the tag but do not create a GitHub release.
#       --branch B   Integration branch to release from (default: swift).
#   -h, --help       Show this help.
#
set -euo pipefail

# --- configuration -----------------------------------------------------------

UPSTREAM_REMOTE="upstream"
UPSTREAM_URL="https://github.com/libarchive/libarchive.git"
ORIGIN_REMOTE="origin"
BRANCH="swift"
TEST_CMD=(swift test -c release --parallel)

ASSUME_YES=0
DRY_RUN=0
RUN_TESTS=1
DO_RELEASE=1
VERSION_ARG=""

# --- helpers -----------------------------------------------------------------

prog="$(basename "$0")"

die()  { printf '%s: error: %s\n' "$prog" "$*" >&2; exit 1; }
info() { printf '\033[1m==>\033[0m %s\n' "$*" >&2; }
note() { printf '    %s\n' "$*" >&2; }

# run CMD...: echo it, and execute unless --dry-run.
run() {
  printf '\033[2m+ %s\033[0m\n' "$*" >&2
  if [ "$DRY_RUN" -eq 1 ]; then return 0; fi
  "$@"
}

usage() {
  # print the leading comment block (skip the shebang, stop at the first
  # non-comment line), stripping the leading "# ".
  awk 'NR==1 && /^#!/ {next} /^#/ {sub(/^# ?/,""); print; next} {exit}' "$0"
  exit "${1:-0}"
}

# --- argument parsing --------------------------------------------------------

while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes)     ASSUME_YES=1 ;;
    --dry-run)    DRY_RUN=1 ;;
    --no-test)    RUN_TESTS=0 ;;
    --no-release) DO_RELEASE=0 ;;
    --branch)     shift; [ $# -gt 0 ] || die "--branch requires an argument"; BRANCH="$1" ;;
    --branch=*)   BRANCH="${1#*=}" ;;
    -h|--help)    usage 0 ;;
    -*)           die "unknown option: $1 (try --help)" ;;
    *)
      [ -z "$VERSION_ARG" ] || die "unexpected extra argument: $1"
      VERSION_ARG="$1"
      ;;
  esac
  shift
done

# --- preconditions -----------------------------------------------------------

command -v git >/dev/null 2>&1 || die "git is not installed"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository"
cd "$(git rev-parse --show-toplevel)"

if [ "$RUN_TESTS" -eq 1 ]; then
  command -v swift >/dev/null 2>&1 || die "swift is not installed (use --no-test to skip)"
fi
if [ "$DO_RELEASE" -eq 1 ]; then
  command -v gh >/dev/null 2>&1 || die "gh (GitHub CLI) is not installed (use --no-release to skip)"
fi

# Working tree must be clean: we are about to merge and tag.
if ! git diff --quiet || ! git diff --cached --quiet; then
  die "working tree has uncommitted changes; commit or stash them first"
fi

git show-ref --verify --quiet "refs/heads/$BRANCH" \
  || die "branch '$BRANCH' does not exist locally"

# Ensure the upstream remote exists (one-time setup, per README-SWIFT.md).
if ! git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
  info "Adding '$UPSTREAM_REMOTE' remote -> $UPSTREAM_URL"
  run git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
fi
git remote get-url "$ORIGIN_REMOTE" >/dev/null 2>&1 \
  || die "remote '$ORIGIN_REMOTE' is not configured"

# --- 1. fetch upstream tags --------------------------------------------------

info "Fetching tags from '$UPSTREAM_REMOTE'"
git fetch --tags "$UPSTREAM_REMOTE" \
  || die "failed to fetch from '$UPSTREAM_REMOTE' (check network/remote)"

# --- resolve the version to release ------------------------------------------

normalize_version() {
  # accept "3.8.7" or "v3.8.7", emit "v3.8.7"
  local v="$1"
  v="v${v#v}"
  printf '%s' "$v"
}

if [ -n "$VERSION_ARG" ]; then
  VERSION="$(normalize_version "$VERSION_ARG")"
  info "Using requested version: $VERSION"
else
  info "No version given; resolving most recent upstream release tag"
  VERSION="$(
    git ls-remote --tags --refs "$UPSTREAM_REMOTE" 'v*' \
      | awk -F/ '{print $NF}' \
      | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
      | sort -V \
      | tail -n 1
  )"
  [ -n "$VERSION" ] || die "could not determine the latest upstream release tag"
  info "Latest upstream release tag: $VERSION"
fi

NUM="${VERSION#v}"

# The tag must exist upstream (so we can merge it).
git rev-parse -q --verify "refs/tags/$VERSION^{commit}" >/dev/null 2>&1 \
  || die "tag '$VERSION' not found among upstream tags"

# --- 2. merge the upstream release into the overlay branch -------------------

info "Checking out '$BRANCH'"
run git checkout "$BRANCH"

info "Merging upstream '$VERSION' into '$BRANCH' (additive overlay → no conflicts expected)"
if [ "$DRY_RUN" -eq 1 ]; then
  note "(dry-run) would run: git merge --no-edit $VERSION"
elif ! git merge --no-edit "$VERSION"; then
  git merge --abort 2>/dev/null || true
  die "merge of '$VERSION' into '$BRANCH' produced conflicts; resolve manually"
fi

# --- 3. build & test ---------------------------------------------------------

if [ "$RUN_TESTS" -eq 1 ]; then
  info "Building and testing the Swift package"
  run "${TEST_CMD[@]}"
else
  note "Skipping build/test (--no-test)"
fi

# --- invariant check: the tagged commit must carry the manifest --------------

if [ "$DRY_RUN" -eq 0 ]; then
  git ls-tree --name-only HEAD | grep -qx 'Package.swift' \
    || die "HEAD of '$BRANCH' has no Package.swift; refusing to release"
fi

# --- confirmation ------------------------------------------------------------

TARGET_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo '?')"
info "Ready to release:"
note "version:  $VERSION  (libarchive $NUM + Swift overlay)"
note "branch:   $BRANCH @ $TARGET_SHA"
note "tag push: force-update '$VERSION' on '$ORIGIN_REMOTE' (overrides the upstream-mirrored tag)"
note "release:  $([ "$DO_RELEASE" -eq 1 ] && echo "gh release create $VERSION" || echo "skipped (--no-release)")"

if [ "$DRY_RUN" -eq 1 ]; then
  info "Dry run complete; no changes pushed."
  exit 0
fi

if [ "$ASSUME_YES" -ne 1 ]; then
  if [ ! -t 0 ]; then
    die "refusing to push without confirmation; re-run with --yes in a non-interactive shell"
  fi
  printf 'Proceed? [y/N] ' >&2
  read -r reply
  case "$reply" in
    y|Y|yes|YES) ;;
    *) die "aborted by user" ;;
  esac
fi

# --- 4. push branch, then re-tag and force-push ------------------------------

info "Pushing '$BRANCH' to '$ORIGIN_REMOTE'"
run git push "$ORIGIN_REMOTE" "$BRANCH"

info "Tagging '$VERSION' on $TARGET_SHA"
run git tag -f -a "$VERSION" -m "libarchive $NUM + Swift overlay"

info "Force-pushing tag '$VERSION' to '$ORIGIN_REMOTE'"
run git push "$ORIGIN_REMOTE" -f "$VERSION"

# Confirm the pushed tag is SwiftPM-consumable.
git ls-tree --name-only "$VERSION" | grep -qx 'Package.swift' \
  || die "tag '$VERSION' does not contain Package.swift after tagging"
info "Verified: tag '$VERSION' includes Package.swift"

# --- 5. publish the GitHub release -------------------------------------------

if [ "$DO_RELEASE" -eq 1 ]; then
  # Derive owner/repo from the origin URL (fallback to marcprux/swift-archive).
  origin_url="$(git remote get-url "$ORIGIN_REMOTE")"
  REPO="$(printf '%s' "$origin_url" \
    | sed -E 's#^git@github.com:#https://github.com/#; s#\.git$##' \
    | sed -E 's#^https?://github.com/##')"
  [ -n "$REPO" ] || REPO="marcprux/swift-archive"

  if gh release view "$VERSION" --repo "$REPO" >/dev/null 2>&1; then
    info "Replacing existing GitHub release '$VERSION'"
    run gh release delete "$VERSION" --repo "$REPO" --yes
  fi

  info "Creating GitHub release '$VERSION' on $REPO"
  run gh release create "$VERSION" \
    --repo "$REPO" \
    --title "$VERSION" \
    --notes "Based on libarchive $NUM with the Swift Package overlay."
else
  note "Skipping GitHub release (--no-release)"
fi

info "Done: $VERSION released."
