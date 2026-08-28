#!/usr/bin/env bash
# bootstrap-release.sh - Standard npm release flow per publish-kit REFERENCE.md section A.
# Usage: ./bootstrap-release.sh patch|minor|major
#
# For exe projects (PyInstaller / Go single-binary / Rust single-binary / Electron):
# see scripts/release-exe.sh <pyinstaller|go|rust|electron> <app> <version>

set -euo pipefail
cd "$(dirname "$0")"

BUMP="${1:-patch}"
REGISTRY="${NPM_REGISTRY:-https://registry.npmjs.org/}"
COMMIT_PREFIX="${COMMIT_PREFIX:-chore: release}"

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log() { echo -e "${2:-$NC}$1${NC}"; }

log "=== bootstrap-release.sh ($BUMP) ===" "$CYAN"

# Step 1: bump
log "[1/6] bump version ($BUMP)" "$YELLOW"
CURRENT=$(node -p "require('./package.json').version")
npm version "$BUMP" --no-git-tag-version >/dev/null
NEW=$(node -p "require('./package.json').version")
log "    $CURRENT -> $NEW"

# Step 2: test + build
log "[2/6] test + build" "$YELLOW"
npm test
if grep -q '"build"' package.json; then npm run build; fi

# Step 3: commit
log "[3/6] commit" "$YELLOW"
git add -A
git commit -m "$COMMIT_PREFIX v$NEW" --allow-empty

# Step 4: npm publish
log "[4/6] npm publish --registry=$REGISTRY" "$YELLOW"
TOKEN_FILE=".npmrc.publish"
trap 'rm -f "$TOKEN_FILE"' EXIT
if [[ ! -f "$TOKEN_FILE" ]]; then
    echo -n "    enter npm auth token: " >&2
    read -rs token
    echo
    echo "//registry.npmjs.org/:_authToken=$token" > "$TOKEN_FILE"
fi
npm publish --registry="$REGISTRY" --access public

# Step 5: tag + push both remotes
log "[5/6] git tag v$NEW + push" "$YELLOW"
git tag -a "v$NEW" -m "v$NEW"
SUBJECT=$(git show "v$NEW" --no-patch --format='%s')
log "    verified tag subject: $SUBJECT"
git push origin main --tags
if git remote get-url gitee >/dev/null 2>&1; then
    git push gitee main --tags || log "    WARN: gitee push failed" "$YELLOW"
fi

# Step 6: GitHub RP fields
log "[6/6] GitHub RP fields" "$YELLOW"
ORIGIN=$(git remote get-url origin 2>/dev/null || true)
if [[ "$ORIGIN" =~ github.com[:/](.+)/(.+)\.git$ ]]; then
    REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    read -rp "    repository description: " DESCRIPTION
    read -rp "    topics (comma-separated): " TOPICS_RAW
    TOPICS_JSON=$(node -e "console.log(JSON.stringify({names: process.argv[1].split(',').map(s=>s.trim()).filter(Boolean)}))" "$TOPICS_RAW")
    echo "$TOPICS_JSON" > /tmp/.gh-topics.json
    gh api -X PATCH "repos/$REPO" -f description="$DESCRIPTION" >/dev/null
    gh api -X PUT "repos/$REPO/topics" --input /tmp/.gh-topics.json >/dev/null
    rm -f /tmp/.gh-topics.json
    log "    RP updated"
else
    log "    WARN: cannot infer GitHub repo from origin" "$YELLOW"
fi

log "=== release v$NEW complete ===" "$GREEN"
