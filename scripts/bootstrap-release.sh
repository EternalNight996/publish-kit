#!/usr/bin/env bash
# bootstrap-release.sh - bash mirror of bootstrap-release.ps1
# See REFERENCE.md section A + K, and RELEASE-GRADES.md for the grade table.
#
# GRADES (owner rule: a stable version needs explicit approval):
#   alpha  X.Y.Z-alpha.N  dist-tag alpha   internal preview, self-service
#   beta   X.Y.Z-beta.N   dist-tag beta    public test, self-service (DEFAULT when --grade is omitted)
#   rc     X.Y.Z-rc.N     dist-tag rc      feature-frozen candidate, self-service
#   release X.Y.Z         dist-tag latest  needs approval (PUBLISH_KIT_APPROVED=1 or --approved-by=)
#   patch  X.Y.Z+1        dist-tag latest  needs approval, fixes only
#
#   ./bootstrap-release.sh minor --grade beta                     # v0.4.1-beta.1
#   ./bootstrap-release.sh --grade beta --grade-bump=2            # v0.4.1-beta.2
#   PUBLISH_KIT_APPROVED=1 ./bootstrap-release.sh minor --grade release
#   ./bootstrap-release.sh --grade release --promote-from-beta --promote-version=v0.4.1-rc.1 --approved-by=<owner>
#
# For exe projects see scripts/release-exe.sh.

set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

BUMP="patch"
NPM_REGISTRY="${NPM_REGISTRY:-https://registry.npmjs.org/}"
COMMIT_PREFIX="${COMMIT_PREFIX:-chore: release}"
GRADE="${GRADE:-}"
GRADE_BUMP="${GRADE_BUMP:-1}"
APPROVED_BY="${APPROVED_BY:-}"
PRE_RELEASE="${PRE_RELEASE:-}"
PRE_RELEASE_BUMP="${PRE_RELEASE_BUMP:-1}"
PROMOTE_FROM_BETA="${PROMOTE_FROM_BETA:-}"
PROMOTE_VERSION="${PROMOTE_VERSION:-}"
SKIP_GIT_TAG="${SKIP_GIT_TAG:-}"
SKIP_NPM_PUBLISH="${SKIP_NPM_PUBLISH:-}"
DRY_RUN="${DRY_RUN:-}"

# Both `--flag value` and `--flag=value` are accepted; `patch|minor|major` can appear anywhere.
while [ $# -gt 0 ]; do
    case "$1" in
        --grade)              GRADE="${2:-}"; shift 2 ;;
        --grade=*)            GRADE="${1#*=}"; shift ;;
        --grade-bump)         GRADE_BUMP="${2:-1}"; shift 2 ;;
        --grade-bump=*)       GRADE_BUMP="${1#*=}"; shift ;;
        --approved-by)        APPROVED_BY="${2:-}"; shift 2 ;;
        --approved-by=*)      APPROVED_BY="${1#*=}"; shift ;;
        --pre-release)        PRE_RELEASE="${2:-}"; shift 2 ;;
        --pre-release=*)      PRE_RELEASE="${1#*=}"; shift ;;
        --pre-release-bump)   PRE_RELEASE_BUMP="${2:-1}"; shift 2 ;;
        --pre-release-bump=*) PRE_RELEASE_BUMP="${1#*=}"; shift ;;
        --promote-from-beta)  PROMOTE_FROM_BETA=1; shift ;;
        --promote-version)    PROMOTE_VERSION="${2:-}"; shift 2 ;;
        --promote-version=*)  PROMOTE_VERSION="${1#*=}"; shift ;;
        --skip-git-tag)       SKIP_GIT_TAG=1; shift ;;
        --skip-npm-publish)   SKIP_NPM_PUBLISH=1; shift ;;
        --dry-run)            DRY_RUN=1; shift ;;
        patch|minor|major)    BUMP="$1"; shift ;;
        *)                    shift ;;
    esac
done

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
step() { echo -e "${CYAN}\n=== $* ===${NC}"; }
info() { echo "  $*"; }
warn() { echo -e "${YELLOW}  ! $*${NC}"; }
fail() { echo -e "${RED}  X $*${NC}"; }

if [ ! -f package.json ]; then fail "no package.json"; exit 1; fi
HAS_GH=""
command -v gh >/dev/null 2>&1 && HAS_GH=1

# --- grade normalization: legacy --pre-release <tag> == --grade <tag> ---
if [ -z "$GRADE" ] && [ -n "$PRE_RELEASE" ]; then GRADE="$PRE_RELEASE"; fi
if [ -n "$PRE_RELEASE" ] && [ "$PRE_RELEASE_BUMP" != "1" ]; then GRADE_BUMP="$PRE_RELEASE_BUMP"; fi

DEFAULTED=0
if [ -n "$PROMOTE_FROM_BETA" ]; then
    GRADE=release; MODE=promote
elif [ -z "$GRADE" ]; then
    GRADE=beta; MODE=test; DEFAULTED=1
else
    case "$GRADE" in
        alpha|beta|rc) MODE=test ;;
        release|patch) MODE=stable ;;
        *) fail "unknown grade: $GRADE (allowed: alpha beta rc release patch)"; exit 2 ;;
    esac
fi

approval_ok() {
    [ "${PUBLISH_KIT_APPROVED:-}" = "1" ] && return 0
    [ -n "$APPROVED_BY" ] && return 0
    return 1
}

if [ "$DEFAULTED" = "1" ]; then
    warn "no --grade given: publishing as beta (test build)."
    warn "a stable release/patch needs the owner's approval: PUBLISH_KIT_APPROVED=1 or --approved-by=<owner>"
fi

if [ "$MODE" = "stable" ] || [ "$MODE" = "promote" ]; then
    if ! approval_ok; then
        step "Approval gate"
        fail "grade=$GRADE requires the owner's approval before it can reach dist-tag 'latest'."
        info "pass one of:"
        info "  PUBLISH_KIT_APPROVED=1 $0 $BUMP --grade $GRADE"
        info "  $0 $BUMP --grade $GRADE --approved-by=<owner>"
        info "or publish a test build instead (no approval needed):"
        info "  $0 $BUMP --grade beta"
        exit 2
    fi
    info "approval ok: ${APPROVED_BY:+approved-by=$APPROVED_BY}${APPROVED_BY:-PUBLISH_KIT_APPROVED=1}"
fi

step "Resolve target version"
ORIG_PKG="$(cat package.json)"
PKG_NAME=$(node -p 'require("./package.json").name')
VERSION_EXISTS=0
if [ "$MODE" = "promote" ]; then
    if [ -n "$PROMOTE_VERSION" ]; then
        TARGET_VERSION="$PROMOTE_VERSION"
    else
        TARGET_VERSION="$(npm view "$PKG_NAME" dist-tags.rc --registry="$NPM_REGISTRY" 2>/dev/null || true)"
        [ -z "$TARGET_VERSION" ] && TARGET_VERSION="$(npm view "$PKG_NAME" dist-tags.beta --registry="$NPM_REGISTRY" 2>/dev/null || true)"
        [ -z "$TARGET_VERSION" ] && { fail "no rc/beta dist-tag set; pass --promote-version=vX.Y.Z-<tag>.N"; exit 1; }
    fi
    TARGET_VERSION="${TARGET_VERSION#v}"
    SOURCE_VERSION="$TARGET_VERSION"
    # promote publishes the STABLE version, never the prerelease string: 0.6.0-beta.2 -> 0.6.0
    if [[ "$TARGET_VERSION" =~ ^([0-9]+\.[0-9]+\.[0-9]+)- ]]; then
        TARGET_VERSION="${BASH_REMATCH[1]}"
    fi
    if [ -n "$(npm view "$PKG_NAME@$TARGET_VERSION" version --registry="$NPM_REGISTRY" 2>/dev/null || true)" ]; then
        VERSION_EXISTS=1
        info "Promote: $SOURCE_VERSION -> $TARGET_VERSION already on npm; will move dist-tag latest instead of republishing"
    else
        info "Promote: $SOURCE_VERSION -> stable $TARGET_VERSION (dist-tag latest)"
    fi
elif [ "$MODE" = "test" ]; then
    CUR=$(node -p 'require("./package.json").version')
    if [[ "$CUR" =~ ^(.+)-([a-zA-Z]+)\.([0-9]+)$ ]]; then
        BASE="${BASH_REMATCH[1]}"; CURPRE="${BASH_REMATCH[2]}"; CURNUM="${BASH_REMATCH[3]}"
        if [ "$CURPRE" = "$GRADE" ]; then
            NEWNUM=$((CURNUM + GRADE_BUMP))
        else
            NEWNUM="$GRADE_BUMP"
        fi
        TARGET_VERSION="$BASE-$GRADE.$NEWNUM"
    else
        npm version "$BUMP" --no-git-tag-version >/dev/null
        BASE=$(node -p 'require("./package.json").version')
        TARGET_VERSION="$BASE-$GRADE.$GRADE_BUMP"
    fi
    info "Grade $GRADE target: $TARGET_VERSION (dist-tag: $GRADE, GitHub Pre-release)"
else
    if [ "$GRADE" = "patch" ] && [ "$BUMP" != "patch" ]; then
        warn "grade=patch forces a patch bump (no new features allowed in a patch)"
        BUMP=patch
    fi
    npm version "$BUMP" --no-git-tag-version >/dev/null
    TARGET_VERSION="$(node -p 'require("./package.json").version')"
    info "Grade $GRADE target: $TARGET_VERSION (dist-tag: latest, production release)"
fi

CUR=$(node -p 'require("./package.json").version')
if [ "$TARGET_VERSION" != "$CUR" ]; then
    info "Updating package.json version to $TARGET_VERSION"
    node -e "const p=require('./package.json');p.version=process.argv[1];require('fs').writeFileSync('package.json',JSON.stringify(p,null,2)+'\n');" "$TARGET_VERSION"
fi

if [ "$MODE" = "test" ]; then DIST_TAG="$GRADE"; else DIST_TAG="latest"; fi
if [ "$MODE" = "test" ]; then GH_PRERELEASE="--prerelease"; else GH_PRERELEASE="--prerelease=false"; fi

if [ -n "$DRY_RUN" ]; then
    step "Dry-run summary"
    info "grade: $GRADE ($MODE)"
    info "target version: $TARGET_VERSION"
    info "dist-tag: $DIST_TAG"
    info "git tag: v$TARGET_VERSION"
    info "GitHub Release: $([ "$GH_PRERELEASE" = "--prerelease" ] && echo pre-release || echo production)"
    info "approval: $(if [ "$MODE" = "test" ]; then echo 'not required (test grade)'; elif approval_ok; then echo 'ok'; else echo 'MISSING -> would exit 2'; fi)"
    printf '%s\n' "$ORIG_PKG" > package.json
    info "(package.json restored: dry-run writes nothing)"
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
    step "npm publish (dist-tag: $DIST_TAG)"
    TOKEN_FILE=".npmrc.publish"
    trap 'rm -f "$TOKEN_FILE"' EXIT
    if [ ! -f "$TOKEN_FILE" ]; then
        echo -n "  enter npm auth token: " >&2
        read -rs token
        echo
        echo "//registry.npmjs.org/:_authToken=$token" > "$TOKEN_FILE"
    fi
    if [ "$VERSION_EXISTS" = "1" ]; then
        npm dist-tag add "$PKG_NAME@$TARGET_VERSION" "$DIST_TAG" --registry="$NPM_REGISTRY"
    else
        npm publish --registry="$NPM_REGISTRY" --access public --tag "$DIST_TAG"
    fi
fi

if [ -z "$SKIP_GIT_TAG" ]; then
    step "git tag v$TARGET_VERSION + push"
    git tag -a "v$TARGET_VERSION" -m "v$TARGET_VERSION (grade: $GRADE)"
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
        gh release create "v$TARGET_VERSION" --repo "$REPO" "$GH_PRERELEASE" --title "v$TARGET_VERSION" --generate-notes
    fi
fi

step "Done"
info "grade: $GRADE"
info "version: v$TARGET_VERSION"
info "npm dist-tag: $DIST_TAG"
info "git tag pushed to: origin, gitee (if configured)"
info "GitHub Release: $([ "$GH_PRERELEASE" = "--prerelease" ] && echo pre-release || echo production)"

if [ "$MODE" = "test" ]; then
    echo
    echo -e "${YELLOW}Next: when this $GRADE is validated and the owner approves, promote it to latest:${NC}"
    PKG_NAME=$(node -p 'require("./package.json").name')
    echo -e "${YELLOW}  $0 --grade release --promote-from-beta --promote-version=v$TARGET_VERSION --approved-by=<owner>${NC}"
    echo -e "${YELLOW}  or simply: npm dist-tag add $PKG_NAME@$TARGET_VERSION latest --registry=$NPM_REGISTRY${NC}"
fi
