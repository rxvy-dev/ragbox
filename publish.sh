#!/usr/bin/env bash
# Publish Ragbox to GitHub: pushes the source and creates (or updates) a
# release for the current pubspec version with the APK attached.
#
#   ./publish.sh                 uses rxvy-dev/ragbox
#   REPO=you/yourrepo ./publish.sh
#   REBUILD=1 ./publish.sh       force a fresh APK build first
#
# Requirements: git, GitHub CLI (`gh`) logged in (`gh auth login`), Flutter SDK.
set -euo pipefail
cd "$(dirname "$0")"

REPO="${REPO:-rxvy-dev/ragbox}"
VERSION="$(grep '^version:' pubspec.yaml | sed -E 's/version: *([^+]+).*/\1/')"
TAG="v${VERSION}"
APK="dist/ragbox-${TAG}.apk"

red() { printf '\033[1;31m%s\033[0m\n' "$*"; }
info() { printf '\033[1;37m==> %s\033[0m\n' "$*"; }

for tool in git gh; do
  command -v "$tool" >/dev/null 2>&1 || { red "$tool is not installed."; exit 1; }
done
if ! gh auth status >/dev/null 2>&1; then
  info "Logging in to GitHub"
  gh auth login
fi

if [ ! -f "$APK" ] || [ "${REBUILD:-0}" = 1 ]; then
  info "Building $APK"
  ./build_install.sh --no-install
fi
[ -f "$APK" ] || { red "APK missing: $APK"; exit 1; }

if [ ! -d .git ]; then
  info "Initialising git repository"
  git init -q -b main
fi
git add -A
if ! git diff --cached --quiet; then
  git commit -q -m "Ragbox ${TAG}"
fi
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

if gh repo view "$REPO" >/dev/null 2>&1; then
  if ! git remote get-url origin >/dev/null 2>&1; then
    git remote add origin "https://github.com/${REPO}.git"
  fi
  info "Pushing to $REPO"
  git push -u origin "$BRANCH"
else
  info "Creating public repository $REPO"
  gh repo create "$REPO" --public --source=. --remote=origin --push \
    --description "Free, open-source, offline ragdoll physics sandbox for Android (Flutter)."
fi

NOTES="$(mktemp)"
cat > "$NOTES" <<NOTES_EOF
## Ragbox ${TAG}

Free, open-source ragdoll physics sandbox for Android. No accounts, no ads, no internet.

**Install:** download \`ragbox-${TAG}.apk\` below on your Android phone or tablet and open it
(allow "install unknown apps" for your browser/file manager when asked).

$( [ -f RELEASE_NOTES.md ] && cat RELEASE_NOTES.md )
NOTES_EOF

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  info "Updating release $TAG"
  gh release upload "$TAG" "$APK" --repo "$REPO" --clobber
else
  info "Creating release $TAG"
  gh release create "$TAG" "$APK" --repo "$REPO" --title "Ragbox ${TAG}" --notes-file "$NOTES" --target "$BRANCH"
fi
rm -f "$NOTES"
info "Done: https://github.com/${REPO}/releases/tag/${TAG}"
