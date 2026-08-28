# Publish Kit Reference

Sections A-G and J come from hands-on release experience (npm, DSH plugins, GitHub/Gitee, PyInstaller). Sections H-I (cargo, PyPI) state the standard registry flow; no local crate has been shipped yet, so treat them as baseline, not battle-tested.

## A. Release SOP (npm track)

1. Bump `package.json` version; commit (message includes version).
2. `npm run test`; build runs via `prepublishOnly`.
3. `npm publish --registry=https://registry.npmjs.org/`.
4. `git tag v<x.y.z> <hash>` -> verify -> `git push origin main --tags` -> `git push gitee main --tags`.
5. GitHub RP fields: Description via `PATCH /repos/{owner}/{repo}`; Topics via `PUT /repos/{owner}/{repo}/topics` body `{"names":[...]}`. Topics is a separate endpoint; mixing it into PATCH returns 400.

Token handling: write `//registry.npmjs.org/:_authToken=npm_XXX` into a local `.npmrc` just for the publish, then delete it. Never commit tokens. Local default registry is often npmmirror; always pass `--registry` explicitly for publish/view.

Name taken? Switch to a scoped package `@<user>/<name>` and publish with `--access public`.

npm refuses republishing the same version (403). Doc-only changes need no republish. Check `npm view <pkg> version` first.

## B. DSH plugin marketplace matrix

| Marketplace | Mechanism | Manual step | Checkpoint |
| --- | --- | --- | --- |
| npm | publish | yes | version + files whitelist |
| GitHub / Gitee | git push | yes | tags pushed both remotes |
| awesome-dsh-plugin | PR | yes | add `data/plugins/<owner>__<repo>.yml`, regen README via `node scripts/generate-readme.mjs`, `gh pr create` |
| dsh-market (2BingLing) | Issue | yes | `gh issue create` per template, reference Issue #30 style |
| dsh-marketplace (ouyangyipeng) | scans topic `dsh-plugin` | no | public repo + topic |
| dsh-plugin-marketplace (YELEBAI) | scans topic every 2h | no | topic + `package.json#dsh.marketplace` |
| dsh-find-plugin | searches topic | no | topic + public repo |

`dsh.marketplace` metadata example:

```json
"dsh": { "marketplace": { "profiles": ["web"], "requiresBuildApproval": false, "requiresRestart": true, "manualSteps": false } }
```

package.json for listing: `keywords` must include `dsh-plugin`; `repository`, `homepage`, `author`, `license` (MIT), `publishConfig.registry` set. YAML/data files must be UTF-8 without BOM (js-yaml fails on BOM; write with `UTF8Encoding($false)`).

## C. npm publish details

- files whitelist: only shipping artifacts (`index.js`, `lib`, `cordis.patch.yml`, `README*.md`, `LICENSE`, runtime assets). Exclude `src/ tests/ build.mjs/ preview/` and showcase assets.
- peerDependencies semver: prefer the widest safe range, e.g. ">=0.1.0-rc.2 <0.2.0" covers the whole 0.1.x line; `^0.1.1-rc.2` silently rejects older 0.1.0-rc.x hosts. `^0.1.0` pins forever once 0.2.x ships and `dsh plugin add` never refreshes an existing entry's range.
- pnpm workspace (`~/.dsh/profiles/<profile>`): use `pnpm add <pkg>@<ver>`, never `npm install` (link: protocol is pnpm-only). Restart the host app or hard-reload to load new client bundles.
- npx trap: npx pulls latest from npmjs when it cannot find the CLI locally; lock with `npx @deepseek-ai/dsh@<same-version-as-desktop> ...`, or call the desktop's bundled CLI directly.
- Host code changes need a full process restart; refreshing the page only reloads the client.

## D. npm package slimming

1. README showcase media -> GitHub raw URLs (`https://raw.githubusercontent.com/OWNER/REPO/BRANCH/path`). Renders on GitHub, Gitee, and npmjs.
2. Remove showcase assets from the `files` whitelist. Keep them in git (not in .gitignore) so both repo hosts still show them.
3. `files` whitelist controls the tarball; `.gitignore` controls the repo. They are independent; full on GitHub/Gitee, tiny on npm.
4. Never exclude runtime assets the client references (ASSET_BASE, theme image URLs). Test: showcase = only paths referenced by README `<img>`.
5. Before shipping: `npm pack --dry-run` to review contents and size. Observed result: 10 MB -> 50 KB.
6. GIF over ~10 MB will not render in GitHub README. Compress: `ffmpeg -y -i in.gif -filter_complex "fps=6,scale=640:-2,split[a][b];[a]palettegen=max_colors=64[p];[b][p]paletteuse" -loop 0 out.gif`.

## E. git tag SOP

- Tag the commit whose message declares the version, resolved from `git log --oneline --all`. Never guess with `commit~N` (non-linear history + wrong anchor = phantom tags).
- Verify every tag before pushing: `git show <tag> --no-patch --format=%s`; delete mistakes with `git tag -d`.
- Missing versions in the log are normal; do not fabricate tags for them.
- PowerShell has no `&&`; chain commands with `;`.

## F. README design spec

- Bilingual as separate files: `README.md` (zh) + `README.en.md` (en); each starts with a language switch row; npm/GitHub render `README.md` only, so keep both in the files whitelist.
- Section order: centered banner (logo/GIF) -> centered title + subtitle -> badge row (npm version / MIT / GitHub) -> language row -> one-line purpose (zh/en) -> screenshots (GIF first, then PNGs) -> Install (one canonical command) -> Features table -> Build -> Changelog -> Roadmap -> License.
- For product-grade rewrites: lead with a pain-point table, then Before/After mapping, one core-flow diagram (Mermaid may not render on some hosts; offer a static table), differentiate against known projects, close with an expanded roadmap.
- Keep the package.json version and the changelog version in lockstep.

## G. GitHub + Gitee dual remote

- Remotes as SSH: `git@github.com:<user>/<repo>.git` and `git@gitee.com:<user>/<repo>.git`; publish scripts must force-reset existing remotes (`git remote remove` + add), or stale HTTPS/old-project URLs survive.
- One-shot publish script pattern (`publish.bat`): replace `YOUR_USER` placeholders, create empty same-name repos on both hosts, add the printed SSH public key to both accounts, rerun to push. Auto-generate ed25519 keys if missing; skip `ssh -T` (hangs on host fingerprint prompt without keys).
- bat files: full-width punctuation (：「」（）) inside echo gets parsed as commands; keep punctuation ASCII.
- gitignore build artifacts: `build/ dist/ out/ logs/ *.spec config.json crash.log`.

## H. cargo / crates.io (standard flow, not yet battle-tested here)

1. `cargo login` with a crates.io API token (https://crates.io/settings/tokens).
2. `Cargo.toml` metadata: `name`, `version`, `edition`, `description`, `license`, `repository`, `readme`; optional `keywords` (max 5), `categories` (from https://crates.io/category_slugs).
3. `cargo publish --dry-run` to validate the package, then `cargo publish`. Crates are immutable: a version can never be republished or overwritten; yanking hides from new resolves but does not delete.
4. Tag the release (`git tag v<x.y.z>` + push) in the same session; keep `Cargo.toml` version and the tag in lockstep.

## I. PyPI / PyInstaller exe

- Standard PyPI: `python -m build` then `twine upload dist/*` with a token from https://pypi.org/manage/account/token/; versions are immutable, same as npm.
- PyInstaller frozen paths: `__file__` points at the temp `_MEIPASS`; anchor user-visible output on the directory of `sys.executable` so config/logs land next to the exe.
- Build failures on stale `build/<name>/base_library.zip`: taskkill the running exe, force-delete `build/`, the old `.spec`, and old exe before rebuilding; drop `--clean` if it fights the cache.
- Smoke test: launch the exe; absence of a new `crash.log` is the pass signal.

## J. Pitfall quick table

| Symptom | Root cause | Fix |
| --- | --- | --- |
| npx wants to download the CLI | not found in cwd/parents/PATH | lock version or use bundled CLI |
| publish 403 cannot publish over | same version republish | bump version; doc-only changes need none |
| EUNSUPPORTEDPROTOCOL "link:" | npm cannot handle pnpm link: protocol | use `pnpm add` |
| js-yaml invalid YAML / end of stream | BOM in the yml file | write UTF-8 without BOM |
| README GIF invisible on GitHub | over ~10 MB | ffmpeg compress (section D6) |
| plugin install stuck on old version | `^0.1.0` range + min-release-age pinning | widen range; refresh `minimumReleaseAgeExclude`; `dsh plugin update` |
| git install needs build approval | prepare script present | ship built `lib/client.js` instead of prepare; document allowBuilds steps in PUBLISH.md |
| phantom tags after backfill | guessed commit positions | verify each tag subject before push; delete wrong ones |
| push goes to old repo URL | stale remote from earlier init | force-reset remotes in publish script |
