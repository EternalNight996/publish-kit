# Publish Kit Worked Examples

Two transcripts: the publish-kit v0.1.0 self-release (skill-bundle track) and a fictional DSH plugin release (full six-step npm flow). Read alongside REFERENCE.md to see the SOP applied.

## Example 1: publish-kit v0.1.0 self-release

Type: skill bundle (not a cordis plugin, so npm publish step is omitted).

### Pre-flight

- Verified the skill-filesystem provider in DSH runtime (`~/.agents/skills/publish-kit/SKILL.md`).
- Verified SKILL.md <100 lines, frontmatter valid, Use when sentence present.
- Confirmed the description in the catalog matches the SKILL.md frontmatter.

### Steps executed

1. `git init -b main` in `F:\MyApp\eternal\publish-kit`.
2. Added `.gitignore`, `LICENSE` (MIT), `CHANGELOG.md` (Keep a Changelog format).
3. Wrote top-level `README.md` (taste-skill section structure).
4. Added `.claude-plugin/plugin.json` + `marketplace.json` so `npx skills add <repo>` picks it up.
5. Added `scripts/bootstrap-release.ps1` and `scripts/bootstrap-release.sh`.
6. Initial commit `chore: initial publish-kit skill bundle (v0.1.0)`.
7. Commit `docs: add README.md and .claude-plugin manifest for Vercel CLI discoverability`.
8. `gh repo create EternalNight996/publish-kit --public --description "..."`.
9. `git push -u origin main`.
10. GitHub topics via API with names [dsh-skill, agent-skills, publishing, release, npm, cargo, pypi].
11. `git tag -a v0.1.0 -m 'v0.1.0: initial publish-kit skill bundle' 4e72c0b`.
12. `git show v0.1.0 --no-patch --format='%s'` -> README commit message (verified).
13. `git push origin v0.1.0` -> `refs/tags/v0.1.0` confirmed via `git ls-remote origin`.
14. Forked `awesome-dsh-plugin/awesome-dsh-plugin` to `EternalNight996/awesome-dsh-plugin`.
15. Added `data/plugins/EternalNight996__publish-kit.yml` with `category: skill`.
16. `node scripts/generate-readme.mjs` -> 1272 entries regenerated.
17. `gh pr create --repo awesome-dsh-plugin/awesome-dsh-plugin --base main --head EternalNight996:add-publish-kit --title 'Add EternalNight996/publish-kit plugin (skill category)'` -> PR #3554.
18. `gh issue create --repo 2BingLing/dsh-market --title '[提交工具] publish-kit'` -> Issue #94.

### Lessons from this run

- Gitee API POST `/user/repos` returned HTTP 400 with an HTML body (no JSON error). Workaround: create the Gitee repo manually at https://gitee.com/projects/new, then `git push -u gitee main` works as expected. The token pulled from `git credential fill` is sufficient for git operations but not for the API write path.
- `gh topic -f names=...` interprets the value as a string (not a JSON array). Use `gh api --input <file>` with a JSON file instead.
- PowerShell surfaces `git push` "Everything up-to-date" as stderr with exit 1. The push succeeds; check `git ls-remote` for confirmation rather than the exit code.
- The awesome-dsh-plugin repo accepts `category: skill` (see CAT_IDS in `scripts/lib/entries.mjs`). Other useful categories for tooling releases: `tools`, `workflow`, `dev`.

## Example 2: DSH plugin release (full six-step npm flow)

Type: cordis plugin shipped to npm + four DSH marketplaces.

### Files in scope (per TEMPLATE.md)

- `package.json` (TEMPLATE.md section A)
- `cordis.patch.yml`
- `README.md` + `README.en.md` (TEMPLATE.md section E)
- `PUBLISH.md` (TEMPLATE.md section F)
- `index.js`, `lib/client.js` (build artifact)

### Step-by-step

```bash
# 1. version bump
npm version patch --no-git-tag-version
git add package.json
git commit -m "chore: release v0.2.7"

# 2. tests + build
npm test
node build.mjs   # prepublishOnly also runs this automatically

# 3. npm publish (throwaway token)
echo "//registry.npmjs.org/:_authToken=$NPM_TOKEN" > .npmrc.publish
npm publish --registry=https://registry.npmjs.org/ --access public
rm .npmrc.publish

# 4. git tag (anchored to the version commit, verified)
git tag -a v0.2.7 -m 'v0.2.7'
git show v0.2.7 --no-patch --format='%s'

# 5. push both remotes
git push origin main --tags
git push gitee main --tags

# 6. GitHub RP fields + topics
gh api -X PATCH repos/<owner>/<repo> -f description="..."
gh api -X PUT repos/<owner>/<repo>/topics --input topics.json

# 7. Marketplace submissions
#    awesome-dsh-plugin: PR adding data/plugins/<owner>__<repo>.yml
gh pr create --repo awesome-dsh-plugin/awesome-dsh-plugin --head <fork-user>:add-<pkg> --base main --title "Add <owner>/<repo>"

#    dsh-market: Issue
gh issue create --repo 2BingLing/dsh-market --title "[提交插件] <pkg>"

#    dsh-plugin-marketplace: no action needed (auto-scan by topic dsh-plugin)
```

### Pitfalls to expect (per REFERENCE.md section J)

| Symptom | Action |
| --- | --- |
| `npm publish` 403 cannot publish over | bump version; check `npm view <pkg> version` first |
| `EUNSUPPORTEDPROTOCOL "link:"` | use `pnpm add`, not `npm install`, in DSH profiles |
| js-yaml invalid YAML / end of stream | write UTF-8 without BOM (`UTF8Encoding($false)` in .NET, no `BOM` marker in Python) |
| GitHub topic update returns 422 "names not array" | send JSON via `--input` file, not `-f` string |
| README GIF not rendering | compress with ffmpeg (REFERENCE.md D6) |
| Tag pushed to wrong commit | delete with `git tag -d v<x.y.z>`, recreate from resolved hash |
| .bat echo full-width punctuation parsed as command | switch all punctuation in `.bat` to ASCII |

## Example 3: Rust CLI release (exe matrix via GitHub Actions)

Type: standalone Rust binary distributed via GitHub Releases (no npm, no separate registry).

### Pre-flight

- `Cargo.toml` with `[package].name`, `version`, `description`, `repository`, `license` set.
- `rustup` installed locally; targets installed via `rustup target add <triple>`.
- GitHub repo with Actions enabled.
- No package registry involved: every artifact lands on the GitHub Release page.

### Steps executed (locally + CI)

1. Bump version in `Cargo.toml` (manual edit; commit with version number in message).
2. Commit + push to trigger CI on the tag.
3. `git tag -a v1.0.0 <hash>` after verifying.
4. `git push origin main --tags`.
5. CI matrix runs in parallel on ubuntu-latest / windows-latest / macos-latest:
   - ubuntu-latest -> x86_64-unknown-linux-gnu binary
   - windows-latest -> x86_64-pc-windows-msvc + .exe
   - macos-latest (x86_64) -> x86_64-apple-darwin
   - macos-latest (arm64) -> aarch64-apple-darwin
6. Release job downloads all 4 artifacts, computes `sha256sum **/mycli-* > SHA256SUMS`.
7. `softprops/action-gh-release@v2` uploads each artifact + the SHA256SUMS file to a GitHub Release with auto-generated notes.

### Local equivalent (without CI)

```bash
./scripts/release-exe.sh rust mycli 1.0.0 \
  "x86_64-unknown-linux-gnu,x86_64-pc-windows-msvc,x86_64-apple-darwin,aarch64-apple-darwin"
# equivalent on Windows:
# .\scripts\release-exe.ps1 -ProjectType rust -AppName mycli -Version 1.0.0 \
#   -RustTargets x86_64-unknown-linux-gnu,x86_64-pc-windows-msvc,x86_64-apple-darwin,aarch64-apple-darwin
```

What the script does, end-to-end:
1. Resolves repo root from `git rev-parse --show-toplevel`; sanity-checks `gh` is on PATH and `origin` is a GitHub URL.
2. Removes `./dist` and recreates it.
3. For each target triple, runs `rustup target add`, `cargo build --release --target <triple>`, then `mv`s the resulting binary into `./dist/mycli-1.0.0-<target>`.
4. Computes SHA256 of every artifact and writes `./dist/SHA256SUMS`.
5. `git add -A` + commit + `git tag -a v1.0.0` + `git push origin main --tags`.
6. `gh release create v1.0.0 --repo <owner>/<repo> --generate-notes` with every artifact + SHA256SUMS attached.

### Pitfalls specific to exe releases

| Symptom | Action |
| --- | --- |
| `rustup target add <triple>` fails offline | the GitHub Actions runner has internet, so the matrix step is fine; locally fetch the target ahead of time |
| Windows code signing fails (`signtool` exit non-zero) | the cert EV pass is required; add `secrets.WINDOWS_CERT_BASE64` + `secrets.WINDOWS_CERT_PASSWORD`; place signtool step before `upload-artifact` |
| macOS Gatekeeper rejects unsigned binary | add `xcrun notarytool` step; needs Apple Developer ID + `secrets.APPLE_ID` + `secrets.APPLE_PWD` |
| Release job fails to find artifacts | the upload-artifact `name` must match the download-artifact `path` glob; check the `if-no-files-found` setting on upload-artifact |
| `gh release create` upload fails with 403 | `GITHUB_TOKEN` needs `contents: write` in the workflow permissions block |
| Linux glibc version mismatch (binary won't run on older systems) | switch target to `x86_64-unknown-linux-musl` for a static binary |
| ARM Mac build missing universal binary hint | document in release notes: `aarch64-apple-darwin` is required separately; macOS Universal Binary needs a third lipo step |

### When to use the local script vs CI

- Use **`scripts/release-exe.sh`** for one-off releases, ad-hoc experiments, or when you cannot run Actions.
- Use **GitHub Actions workflow (K.3)** for reproducible, audited, multi-contributor projects where every release must trace back to a CI run.
- Both produce the same artifact naming convention (`<app>-<version>-<os>-<arch>` or `<app>-<version>-<target>`), so downstream tooling (brew formulas, scoop manifests, package repos) can consume either path identically.
