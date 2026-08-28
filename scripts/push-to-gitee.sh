#!/usr/bin/env bash
# push-to-gitee.sh - bash mirror of push-to-gitee.ps1
# Use AFTER manually creating the empty Gitee repo at
# https://gitee.com/eternalnight996/publish-kit (public, no init).

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

GITEE_USER="${GITEE_USER:-eternalnight996}"
REPO="${REPO_NAME:-publish-kit}"

git remote remove gitee 2>/dev/null || true
git remote add gitee "git@gitee.com:${GITEE_USER}/${REPO}.git"

echo "Pushing main + all tags..."
git push -u gitee main

EXISTING=$(git ls-remote --tags gitee 2>/dev/null | awk '{print $2}' | sed 's|refs/tags/||')
LOCAL=$(git tag --list)
for t in $LOCAL; do
    if echo "$EXISTING" | grep -qx "$t"; then continue; fi
    echo "  pushing tag $t"
    git push gitee "refs/tags/$t"
done

echo
echo "--- Gitee mirror sync complete ---"
echo "Repo: https://gitee.com/${GITEE_USER}/${REPO}"
echo "Tip: create Releases at https://gitee.com/${GITEE_USER}/${REPO}/releases/new for each tag"
