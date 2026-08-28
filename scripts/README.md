# Scripts

This directory contains the publish-kit automation scripts. Two are dual-OS (PowerShell + bash); the others are Node ESM.

## bootstrap-release.{ps1,sh} — npm release SOP

Standard six-step release for npm packages: bump version, test + build, commit, npm publish (with throwaway `.npmrc.publish` cleaned in `finally` / `trap`), git tag + push both remotes, GitHub RP fields.

```bash
# bash
./scripts/bootstrap-release.sh patch    # or minor | major

# PowerShell
.\scripts\bootstrap-release.ps1 -BumpType patch
```

For exe projects, see `release-exe.*`.

## release-exe.{ps1,sh} — exe project release

Cross-platform build + checksum + GitHub Release upload for PyInstaller / Go / Rust / Electron desktop apps.

```bash
./scripts/release-exe.sh rust mycli 1.0.0 "x86_64-unknown-linux-gnu,x86_64-pc-windows-msvc,x86_64-apple-darwin"

.\scripts\release-exe.ps1 -ProjectType rust -AppName mycli -Version 1.0.0
```

Supported project types:

- `pyinstaller` — single-file exe via `pyinstaller --onefile`
- `go` — cross-compile matrix (default `linux,darwin,windows × amd64,arm64`)
- `rust` — `rustup target add` + `cargo build --release` (4 default targets)
- `electron` — `electron-builder --publish never`

Output: artifacts named `<app>-<version>-<target>.<ext>` + `SHA256SUMS`, uploaded to GitHub Release.

## release-doctor.mjs — pre-flight checker

Runs the REFERENCE.md J pitfall table against the current state of a target repo. Reports drift before the publish step runs.

```bash
node scripts/release-doctor.mjs [target-dir]               # all tracks
node scripts/release-doctor.mjs --track npm               # only npm checks
node scripts/release-doctor.mjs --track dsh-plugin       # only DSH plugin
node scripts/release-doctor.mjs --strict                  # exit 1 on WARN
```

Checks include: git clean / tag at HEAD / version-sync / npm 403 prevention / peerDependency ranges / files whitelist / `dsh.marketplace` metadata / lockfile / README / CHANGELOG / LICENSE / GitHub + Gitee remotes / GitHub description + topics / .bat ASCII-only.

Exit code: 1 on FAIL, 1 on WARN under `--strict`, 0 otherwise.

## verify-release.mjs — post-publish verifier

Walks every channel a publish touches and reports per-channel status. Run AFTER release scripts complete to catch failures (e.g. tag pushed but npm publish failed).

```bash
node scripts/verify-release.mjs                # uses latest git tag
node scripts/verify-release.mjs v0.3.0          # explicit version
```

Channels checked:

- npm registry: `npm view <pkg> version` matches
- GitHub Releases: tag has a published release (not draft)
- Gitee: tag exists on gitee remote
- GitHub topics: required topics still set
- GitHub description: still set
- awesome-dsh-plugin: `data/plugins/<owner>__<repo>.yml` is merged
- dsh-market: an Issue exists for this repo
- GitHub Actions CI: latest run on the tag commit succeeded
- working tree clean

Exit code: 1 on FAIL, 0 otherwise.

## postinstall.js — npm postinstall hook

Runs automatically when `@eternalnight/publish-kit` is installed via `npm install -g` or `dsh plugin add`. Symlinks the bundled `.agents/skills/publish-kit/` into the active user's `~/.agents/skills/`, `~/.claude/skills/`, `~/.codex/skills/`, `~/.gemini/skills/`, and `~/.dsh/skills/` directories (any that exist on the target machine).

Manual invocation is not needed; this file is invoked by `npm install` automatically.

## Recommended local dev loop

```bash
# 1. Dry-run check
node scripts/release-doctor.mjs

# 2. Run the release
./scripts/bootstrap-release.sh patch

# 3. Verify every channel
node scripts/verify-release.mjs
```
