#!/usr/bin/env bash
# bootstrap-release.sh - bash mirror of bootstrap-release.ps1
# See REFERENCE.md section A + K for the full SOP.
#
# Two release modes:
#   .prerelease first, then promote:
#   1. ./bootstrap-release.sh patch --pre-release beta              # v0.4.1-beta.1 -> npm next tag + GitHub Pre-release
#   2. iterate:  ./bootstrap-release.sh --pre-release beta --pre-release-bump 2  # v0.4.1-beta.2
#   3. promote:  ./bootstrap-release.sh patch --promote-from-beta    # move v0.4.1-beta.1 -> v0.4.1 latest
#
# For exe projects see scripts/release-exe.sh.

set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

BUMP="${1:-patch}"
NPM_REGISTRY="${NPM_REGISTRY:-https://registry.npmjs.org/}"
COMMIT_PREFIX="${COMMIT_PREFIX:-chore: release}"
PRE_RELEASE="${PRE_RELEASE:-}"
PRE_RELEASE_BUMP="${PRE_RELEASE_BUMP:-1}"
PROMOTE_FROM_BETA="${PROMOTE_FROM_BETA:-}"
PROMOTE_VERSION="${PROMOTE_VERSION:-}"
SKIP_GIT_TAG="${SKIP_GIT_TAG:-}"
SKIP_NPM_PUBLISH="${SKIP_NPM_PUBLISH:-}"
DRY_RUN="${DRY_RUN:-}"

for arg in "$@"; do
    case $arg in
        --pre-release=*)  PRE_RELEASE="${arg#*=}" ;;
        --pre-release-bump=*) PRE_RELEASE_BUMP="${arg#*=}" ;;
        --promote-from-beta) PROMOTE_FROM_BETA=1 ;;
        --promote-version=*) PROMOTE_VERSION="${arg#*=}" ;;
        --skip-git-tag) SKIP_GIT_TAG=1 ;;
        --skip-npm-publish) SKIP_NPM_PUBLISH=1 ;;
        --dry-run) DRY_RUN=1 ;;
        patch|minor|major) BUMP="$arg" ;;
    esac
done

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'
step() { echo -e "${CYAN}\n=== $* ===${NC}"; }
info() { echo "  $*"; }
warn() { echo -e "${YELLOW}  ! $*${NC}"; }
fail() { echo -e "\033[0;31m  X $*${NC}"; }

if [ ! -f package.json ]; then fail "no package.json"; exit 1; fi
HAS_GH=""
command -v gh >/dev/null 2>&1 && HAS_GH=1

step "Resolve target version"

if [ -n "$PROMOTE_FROM_BETA" ]; then
    if [ -n "$PROMOTE_VERSION" ]; then
        TARGET_VERSION="$PROMOTE_VERSION"
    else
        PKG_NAME=$(node -p 'require("./package.json").name')
        TARGET_VERSION="$(npm view "$PKG_NAME" dist-tags.next --registry="$NPM_REGISTRY" 2>/dev/null || true)"
        [ -z "$TARGET_VERSION" ] && { fail "no `next` dist-tag set; pass --promote-version=vX.Y.Z"; exit 1; }
    fi
    info "Promote mode: moving $TARGET_VERSION from dist-tag next -> latest"
elif [ -n "$PRE_RELEASE" ]; then
    CUR=$(node -p 'require("./package.json").version')
    if [[ "$CUR" =~ ^(.+)-([a-zA-Z]+)\.([0-9]+)$ ]]; then
        BASE="${BASH_REMATCH[1]}"; CURPRE="${BASH_REMATCH[2]}"; CURNUM="${BASH_REMATCH[3]}"
        if [ "$CURPRE" = "$PRE_RELEASE" ]; then
            NEWNUM=$((CURNUM + PRE_RELEASE_BUMP))
            TARGET_VERSION="$BASE-$PRE_RELEASE.$NEWNUM"
        else
            TARGET_VERSION="$BASE-$PRE_RELEASE.$PRE_RELEASE_BUMP"
        fi
    else
        npm version "$BUMP" --no-git-tag-version >/dev/null
        CUR=$(node -p 'require("./package.json").version')
        TARGET_VERSION="$CUR-$PRE_RELEASE.$PRE_RELEASE_BUMP"
    fi
    info "Pre-release target: $TARGET_VERSION (dist-tag: $PRE_RELEASE)"
else
    npm version "$BUMP" --no-git-tag-version >/dev/null
    TARGET_VERSION="$(node -p 'require("./package.json").version')"
    info "Production target: $TARGET_VERSION (dist-tag: latest)"
fi

CUR=$(node -p 'require("./package.json").version')
if [ "$TARGET_VERSION" != "$CUR" ]; then
    info "Updating package.json version to $TARGET_VERSION"
    node -e "const p=require('./package.json');p.version=process.argv[1];require('fs').writeFileSync('package.json',JSON.stringify(p,null,2)+'\n');" "$TARGET_VERSION"
fi

if [ -n "$DRY_RUN" ]; then
    step "Dry-run summary"
    info "target version: $TARGET_VERSION"
    info "dist-tag: $([ -n "$PROMOTE_FROM_BETA" ] && echo latest || ([ -n "$PRE_RELEASE" ] && echo "$PRE_RELEASE" || echo latest))"
    info "git tag: v$TARGET_VERSION"
    info "GitHub Release: $([ -n "$PRE_RELEASE" ] || [ -n "$PROMOTE_FROM_BETA" ] && echo pre-release || echo production)"
    exit 0
fi

step "Test + build"
npm test
if node -e 'const p=require("./package.json");process.exit(p.scripts && p.scripts.build?0:1)'; then
    npm run build
fi

step "Commit"
git add -A
git commit -m "$COMMIT_PREFIX v$TARGET_VERSION" --allow-empty || true

if [ -z "$SKIP_NPM_PUBLISH" ]; then
    step "npm publish (dist-tag: $([ -n "$PROMOTE_FROM_BETA" ] && echo latest || ([ -n "$PRE_RELEASE" ] && echo "$PRE_RELEASE" || echo latest)))"
    TOKEN_FILE=".npmrc.publish"
    trap 'rm -f "$TOKEN_FILE"' EXIT
    if [ ! -f "$TOKEN_FILE" ]; then
        echo -n "  enter npm auth token: " >&2
        read -rs token
        echo
        echo "//registry.npmjs.org/:_authToken=$token" > "$TOKEN_FILE"
    fi
    PUBLISH_TAG=$([ -n "$PROMOTE_FROM_BETA" ] && echo latest || ([ -n "$PRE_RELEASE" ] && echo "$PRE_RELEASE" || echo latest))
    npm publish --registry="$NPM_REGISTRY" --access public --tag "$PUBLISH_TAG"
fi

if [ -z "$SKIP_GIT_TAG" ]; then
    step "git tag v$TARGET_VERSION + push"
    git tag -a "v$TARGET_VERSION" -m "v$TARGET_VERSION"
    git show "v$TARGET_VERSION" --no-patch --format='%s'
    git push origin main --tags
    if git remote get-url gitee >/dev/null 2>&1; then
        git push gitee main --tags || warn "gitee push failed (skip if remote not configured)"
    fi
fi

if [ -n "$HAS_GH" ]; then
    step "GitHub Release v$TARGET_VERSION"
    ORIGIN=$(git remote get-url origin 2>/dev/null || true)
    if [[ "$ORIGIN" =~ github\.com[:/](.+)/(.+)\.git$ ]]; then
        REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
        if [ -n "$PRE_RELEASE" ] || [ -n "$PROMOTE_FROM_BETA" ]; then
            PRERELEASE_FLAG="--prerelease"
        else
            PRERELEASE_FLAG="--prerelease=false"
        fi
        gh release create "v$TARGET_VERSION" --repo "$REPO" "$PRERELEASE_FLAG" --title "v$TARGET_VERSION" --generate-notes
    fi
fi

step "Done"
info "version: v$TARGET_VERSION"
if [ -n "$PROMOTE_FROM_BETA" ]; then DT=latest
elif [ -n "$PRE_RELEASE" ]; then DT="$PRE_RELEASE"
else DT=latest
fi
info "npm dist-tag: $DT"
info "git tag pushed to: origin, gitee (if configured)"
if [ -n "$PRE_RELEASE" ] || [ -n "$PROMOTE_FROM_BETA" ]; then PR=pre-release; else PR=production; fi
info "GitHub Release: $PR"

if [ -n "$PRE_RELEASE" ] && [ -z "$PROMOTE_FROM_BETA" ]; then
    echo
    echo -e "${YELLOW}Next: when this prerelease is stable, promote it to latest:${NC}"
    PKG_NAME=$(node -p 'require("./package.json").name')
    echo -e "${YELLOW}  npm dist-tag add $PKG_NAME@$TARGET_VERSION latest --registry=$NPM_REGISTRY${NC}"
fi
