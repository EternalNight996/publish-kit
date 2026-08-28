# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.3] - 2026-08-28

### Added
- `assets/readme-banner.svg` (40 lines): top-of-README visual hook with gradient + accent colors + 6 channel checkmarks + tagline + version stamp. Referenced from both `README.md` and `README.zh.md`.
- New README sections in both languages:
  - **Supported languages & packaging ecosystems** — DSH ecosystem (4 tracks) + non-DSH language libraries (npm, cargo, PyPI, PyInstaller exe, Homebrew, Scoop, Chocolatey, Go module, Docker, Maven Central, NuGet, RubyGems) + tracks publish-kit explicitly does NOT cover.
  - **Skill bundle discovery & inclusion standards** — universal requirements (frontmatter, layout, license), 7-channel inclusion matrix (Vercel CLI, awesome-dsh-plugin, dsh-market, dsh-marketplace, dsh-find-plugin, dsh-plugin-marketplace, dsh-agent-skills), GitHub RP setup, topic taxonomy, social preview, author checklist.
  - **README & repo home: how to maximize clicks** — repo-home elements (social preview, description, topics, pinned repos, About sidebar), README structure table, asset hygiene (banner, GIF size, raw.githubusercontent cross-host, Mermaid + fallback, result-over-command), SEO & shareability, community signals.
- `DSH-DEPLOY.md`: extended with a new "Skill bundle inclusion standard (the canonical checklist)" chapter — required file layout, frontmatter contract, repo-level requirements, marketplace-by-marketplace detailed steps (PR/Issue/auto-scan patterns + npm wrapper), topic checklist, disqualifiers, inclusion boosters.
- New README badge set: Agent Skill bundle, GitHub release, stars, license, DSH-DEPLOY-native, npm opt-in wrapper, cargo crates.io, PyPI/PyInstaller (8 badges total).

## [0.4.0] - 2026-08-28

### Added
- `scripts/release-doctor.mjs` (215 lines): pre-flight checker that walks the REFERENCE.md J 9-row pitfall table against a target repo. 12 checks cover git clean / tag at HEAD / version sync / npm 403 prevention / peer range widths / files whitelist / `dsh.marketplace` metadata / lockfile / README / CHANGELOG / LICENSE / GitHub + Gitee remotes / GitHub description + topics / .bat ASCII-only. Supports `--track={npm,dsh-plugin,cargo,pypi,exe,github-gitee,all}` and `--strict` (WARN treated as FAIL).
- `scripts/verify-release.mjs` (170 lines): post-publish verifier with 9 channels (npm registry version, GitHub Release exists for tag, Gitee tag exists, GitHub topics, GitHub description, awesome-dsh-plugin yml entry merged, dsh-market submission Issue, GitHub Actions CI pass on tag commit, working tree clean).
- `scripts/README.md` (85 lines): usage docs for all 4 scripts + recommended local dev loop.
- `.github/dependabot.yml`: weekly auto-PR for GitHub Actions / npm / Docker dependencies with grouped minor+patch updates.
- `.github/ISSIS_TEMPLATE/release_question.yml`: new release-question template added to existing bug_report + feature_request.
- **GitHub Releases**: created `v0.2.0`, `v0.2.1`, `v0.3.0`, `v0.4.0` with auto-generated release notes (latest marker on `v0.4.0`).
- **Repo settings**: `delete_branch_on_merge=true` (auto-delete PR branches), `allow_update_branch=true` (maintainers can update PRs), `has_discussions=true` (community Q&A enabled).
- **PR #3554** to `awesome-dsh-plugin`: conflicts resolved, `mergeable=MERGEABLE` (was `CONFLICTING` before rebase).

### Mirror to Gitee
- **`scripts/push-to-gitee.{ps1,sh}`**: one-command Gitee mirror sync (use after manual empty repo creation).
- **Gitee mirror complete**: `https://gitee.com/eternalnight996/publish-kit` now has `main` branch + 9 tags (v0.1.0 through v0.4.0). Gitee Description / Topics / Releases require web UI (API write scope limited for the git-only token used).

### npm package published
- **`@eternalnight/publish-kit@0.4.0`** live at https://registry.npmjs.org/. 20 files / 56.6 KB / signed. Includes `release-doctor.mjs`, `verify-release.mjs`, `scripts/README.md`, `push-to-gitee.{ps1,sh}`. GPG-signed by npm registry.

## [0.4.0] - 2026-08-28

### Added
- `scripts/release-doctor.mjs` (215 lines): pre-flight checker that walks the REFERENCE.md J 9-row pitfall table against a target repo. 12 checks cover git clean / tag at HEAD / version sync / npm 403 prevention / peer range widths / files whitelist / `dsh.marketplace` metadata / lockfile / README / CHANGELOG / LICENSE / GitHub + Gitee remotes / GitHub description + topics / .bat ASCII-only. Supports `--track={npm,dsh-plugin,cargo,pypi,exe,github-gitee,all}` and `--strict` (WARN treated as FAIL).
- `scripts/verify-release.mjs` (170 lines): post-publish verifier with 9 channels (npm registry version, GitHub Release exists for tag, Gitee tag exists, GitHub topics, GitHub description, awesome-dsh-plugin yml entry merged, dsh-market submission Issue, GitHub Actions CI pass on tag commit, working tree clean).
- `scripts/README.md` (85 lines): usage docs for all 4 scripts + recommended local dev loop.
- `.github/dependabot.yml`: weekly auto-PR for GitHub Actions / npm / Docker dependencies with grouped minor+patch updates.
- `.github/ISSUE_TEMPLATE/release_question.yml`: new release-question template added to existing bug_report + feature_request.
- **GitHub Releases**: created `v0.2.0`, `v0.2.1`, `v0.3.0`, `v0.4.0` with auto-generated release notes (latest marker on `v0.4.0`).
- **Repo settings**: `delete_branch_on_merge=true` (auto-delete PR branches), `allow_update_branch=true` (maintainers can update PRs), `has_discussions=true` (community Q&A enabled).
- **PR #3554** to `awesome-dsh-plugin`: conflicts resolved, `mergeable=MERGEABLE` (was `CONFLICTING` before rebase).

## [0.3.0] - 2026-08-28

### Added
- `.github/ISSUE_TEMPLATE/bug_report.yml`: bug report template with agent / install-method / release-track dropdowns + env block.
- `.github/ISSUE_TEMPLATE/feature_request.yml`: feature request template with track dropdown + proposal structure.
- `.github/ISSUE_TEMPLATE/release_question.yml`: release question template for "how do I publish X" questions.
- `.github/PULL_REQUEST_TEMPLATE.md`: PR template with house-format checklist + release-flow checklist + test-evidence requirement.
- `.github/CONTRIBUTING.md`: contribution guide with ground rules + local dev loop + coding style for scripts.
- `.github/SECURITY.md`: vulnerability disclosure policy + supported-versions scope.
- `.github/CODE_OF_CONDUCT.md`: Contributor Covenant 2.0.
- `.github/FUNDING.yml`: GitHub Sponsor link.
- `.github/workflows/ci.yml`: 4-job CI (validate-skill, check-readme-links, check-package, check-markdown-toc). Runs on push, PR, and manual dispatch.
- `assets/social-preview.png` (1280x640, 65 KB): GitHub social preview image. Upload via Settings -> General -> Social preview to maximize click-through when the URL is shared.

## [0.2.1] - 2026-08-28

### Changed
- Removed duplicate old Install section in both READMEs (was after Feature tour).
- Marked npm wrapper Roadmap entry as completed in both languages (v0.2.0 npm publication supersedes it).

## [0.2.0] - 2026-08-28

### Added
- **npm package: `@eternalnight/publish-kit`** published at https://registry.npmjs.org/. Bundles `.agents/skills/publish-kit/` as a tarball asset, ships `bootstrap-release.{ps1,sh}` and `release-exe.{ps1,sh}` as `bin` entries, and includes `cordis.patch.yml` + `dsh.marketplace` metadata so `dsh plugin --profile web add @eternalnight/publish-kit` installs the skill into `~/.agents/skills/` via a postinstall symlink.
- `package.json`: scoped package (`@eternalnight/`), MIT, explicit registry (`https://registry.npmjs.org/`), 19-file tarball (51 KB).
- `cordis.patch.yml`: marker file declaring the package as a skill-wrapper; consumed by `dsh-plugin-marketplace` static validator.
- `scripts/postinstall.js`: auto-symlinks the bundled skill into `~/.agents/skills/`, `~/.claude/skills/`, `~/.codex/skills/`, `~/.gemini/skills/`, `~/.dsh/skills/` on install.
- README: top-of-page **Install** (3 commands: skill bundle / npm / DSH plugin) and **Usage** (model-invoked prompts + CLI examples) sections.
- README: top-of-page **Supported agents & languages** tables (8 agents, 13 languages/ecosystems).
- README badges: replaced `npm-opt-in-wrapper` with `npm-published`.

### Changed
- All references to "not published to npm" updated to reflect the v0.2.0 npm publication. The npm wrapper is no longer opt-in — it is the canonical install path for users who prefer `dsh plugin add` or `npm install -g`.

## [0.1.2] - 2026-08-28

### Changed
- Rewrote top-level `README.md` (243 lines, English) following the dsh-memory-eternal productization pattern: pain table, Before/After mapping, Mermaid flow, core design rationale, competitive differentiation, feature tour, install paths, bundle layout, roadmap, release log, discovery table.
- Clarified npm status: publish-kit is **not published to npm**. The npm wrapper pattern (for users who want `dsh plugin --profile web add publish-kit`) is documented as opt-in in `DSH-DEPLOY.md` and `TEMPLATE.md` section A. No code in the bundle assumes it.

### Added
- New `README.zh.md` (202 lines, Chinese) — Chinese mirror of the rewritten English README, same structure.

## [0.1.1] - 2026-08-28

### Added
- `scripts/bootstrap-release.ps1` and `scripts/bootstrap-release.sh`: six-step release automation (bump version, test, build, commit, npm publish with throwaway token in `finally`-deleted `.npmrc.publish`, tag + push both remotes, GitHub RP fields via API).
- `.agents/skills/publish-kit/EXAMPLES.md`: two worked transcripts (this skill's own v0.1.0 release and a full DSH plugin npm flow) plus a 7-row pitfall table.
- `README.md` script reference section.
- `SKILL.md` See also table extended to include EXAMPLES.md.

## [0.1.0] - 2026-08-28

### Added
- Initial release of publish-kit skill bundle.
- `SKILL.md` (58 lines): frontmatter, quick start, workflow, anti-patterns, checklist, See also table.
- `REFERENCE.md` (103 lines): sections A-J covering npm release SOP, DSH plugin marketplace matrix, peer-dependency semver, npm slimming, git tag SOP, bilingual README spec, dual-remote push, cargo + PyPI baseline, PyInstaller exe build, pitfall quick table.
- `TEMPLATE.md` (316 lines): 10 copy-paste templates (DSH plugin package.json, awesome-dsh-plugin yml entry, dsh-market Issue body, publish.bat, bilingual README, PUBLISH.md, GitHub Actions release, Cargo.toml, pyproject.toml, PyInstaller build).
- `INSTALL.md` (91 lines): four install paths (Vercel `npx skills add`, DSH native, dsh-agent-skills mirror, manual curl).
- `DSH-DEPLOY.md` (67 lines): DSH-specific deployment guide covering six discovery roots, watch semantics, ranks, distribution channels, topic taxonomy.
- `COMPATIBILITY.md` (58 lines): platform matrix for DSH/Claude Code/Codex/Gemini/Cursor/Windsurf/Copilot, frontmatter field support, body-format constraints.
