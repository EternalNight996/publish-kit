#!/usr/bin/env bash
# release-exe.sh - Cross-platform build + checksum + GitHub Release upload.
# Mirrors scripts/release-exe.ps1; use on macOS / Linux.
#
# Usage:
#   ./release-exe.sh pyinstaller <app> 1.0.0 [entry]
#   ./release-exe.sh go <app> 1.0.0 "linux,darwin" "amd64,arm64"
#   ./release-exe.sh rust <app> 1.0.0 "x86_64-unknown-linux-gnu,x86_64-apple-darwin"
#   ./release-exe.sh electron <app> 1.0.0

set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

PROJECT_TYPE="$1"; APP="$2"; VERSION="$3"
DIST="${DIST_DIR:-./dist}"
GITEE_HINT=false

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log() { echo -e "${2:-$NC}$1${NC}"; }

case "$PROJECT_TYPE" in
    pyinstaller|go|rust|electron) ;;
    *) echo "usage: $0 {pyinstaller|go|rust|electron} <app-name> <version> [...]" >&2; exit 1 ;;
esac

command -v gh >/dev/null || { echo "gh CLI required: https://cli.github.com/" >&2; exit 1; }
ORIGIN=$(git remote get-url origin 2>/dev/null || true)
[[ "$ORIGIN" =~ github.com[:/](.+)/(.+)\.git$ ]] || { echo "origin not GitHub: $ORIGIN" >&2; exit 1; }
REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"

rm -rf "$DIST" && mkdir -p "$DIST"

log "=== release-exe.sh ($PROJECT_TYPE) ===" "$CYAN"
log "  App: $APP, Version: $VERSION"

ARTIFACTS=()

case "$PROJECT_TYPE" in
    pyinstaller)
        ENTRY="${4:-}"
        [[ -z "$ENTRY" ]] && { echo "entry script as 4th arg" >&2; exit 1; }
        python -c "import PyInstaller" 2>/dev/null || pip install pyinstaller
        OUT="$APP-$VERSION.exe"
        python -m PyInstaller --onefile --name "$APP" --clean "$ENTRY"
        mv -f "./dist/$APP.exe" "$DIST/$OUT"
        ARTIFACTS+=("$OUT")
        ;;
    go)
        GO_OS="${4:-linux,darwin,windows}"
        GO_ARCH="${5:-amd64,arm64}"
        ENTRY="${6:-main.go}"
        IFS=',' read -ra OSS <<< "$GO_OS"
        IFS=',' read -ra ARCHS <<< "$GO_ARCH"
        for os in "${OSS[@]}"; do
            for arch in "${ARCHS[@]}"; do
                [[ "$os" == "windows" ]] && EXT=".exe" || EXT=""
                OUT="$APP-$VERSION-$os-$arch$EXT"
                log "  building $os/$arch..." "$YELLOW"
                GOOS="$os" GOARCH="$arch" go build -ldflags="-s -w" -o "$DIST/$OUT" "$ENTRY"
                ARTIFACTS+=("$OUT")
            done
        done
        ;;
    rust)
        TARGETS="${4:-x86_64-unknown-linux-gnu,x86_64-apple-darwin,aarch64-apple-darwin,x86_64-pc-windows-msvc}"
        IFS=',' read -ra TGS <<< "$TARGETS"
        for tg in "${TGS[@]}"; do
            [[ "$tg" == *windows* ]] && EXT=".exe" || EXT=""
            OUT="$APP-$VERSION-$tg$EXT"
            log "  building target=$tg..." "$YELLOW"
            rustup target add "$tg" 2>/dev/null || true
            cargo build --release --target "$tg"
            mv -f "./target/$tg/release/$APP$EXT" "$DIST/$OUT"
            ARTIFACTS+=("$OUT")
        done
        ;;
    electron)
        TGTS="${4:-win-x64,mac-x64,mac-arm64,linux-x64}"
        IFS=',' read -ra TS <<< "$TGTS"
        for t in "${TS[@]}"; do
            log "  building electron target=$t..." "$YELLOW"
            npx --yes electron-builder --"$t" --publish never
        done
        for f in ./dist/*; do
            [[ -f "$f" ]] || continue
            case "$f" in
                *.exe|*.dmg|*.AppImage|*.zip|*.deb|*.rpm)
                    base=$(basename "$f")
                    NEW="$APP-$VERSION-$base"
                    mv -f "$f" "$DIST/$NEW"
                    ARTIFACTS+=("$NEW")
                    ;;
            esac
        done
        ;;
esac

[[ ${#ARTIFACTS[@]} -eq 0 ]] && { echo "no artifacts produced" >&2; exit 1; }
log "  built ${#ARTIFACTS[@]} artifact(s):" "$GREEN"
for a in "${ARTIFACTS[@]}"; do log "    - $a"; done

# Checksums
log "  generating sha256..." "$YELLOW"
: > "$DIST/SHA256SUMS"
for a in "${ARTIFACTS[@]}"; do
    (cd "$DIST" && sha256sum "$a" >> SHA256SUMS)
done
cat "$DIST/SHA256SUMS"

# Commit + tag
git add -A
git commit -m "chore: release v$VERSION" --allow-empty || true
git tag -a "v$VERSION" -m "v$VERSION"
git push origin main --tags

# GitHub Release
log "  creating GitHub Release v$VERSION..." "$YELLOW"
DRAFT_FLAG="--draft=false"
[[ "${DRAFT:-}" == "1" ]] && DRAFT_FLAG="--draft"
PRERELEASE_FLAG="--prerelease=false"
[[ "${PRERELEASE:-}" == "1" ]] && PRERELEASE_FLAG="--prerelease"
ARGS=(release create "v$VERSION" --repo "$REPO" $DRAFT_FLAG $PRERELEASE_FLAG --title "v$VERSION" --generate-notes)
for a in "${ARTIFACTS[@]}"; do ARGS+=("$DIST/$a"); done
ARGS+=("$DIST/SHA256SUMS")
gh "${ARGS[@]}"

# Gitee hint
if git remote get-url gitee >/dev/null 2>&1; then
    log "  Gitee mirror: upload artifacts manually via gitee.com UI" "$YELLOW"
fi

log "=== v$VERSION published ===" "$GREEN"
log "  GitHub Release: https://github.com/$REPO/releases/tag/v$VERSION" "$CYAN"
