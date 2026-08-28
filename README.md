<p align="center">
  <img src="assets/readme-banner.svg" alt="Publish Kit — release across every channel without leaving any out" width="100%" />
</p>

<h1 align="center">Publish Kit</h1>

<p align="center">
  <em>The Release Playbook for AI Agents</em>
</p>

<p align="center">
  <a href="./LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License" height="28"/></a>
  &nbsp;
  <a href="https://github.com/vercel-labs/agent-skills"><img src="https://img.shields.io/badge/agent%20skills-compatible-4f46e5" alt="Agent Skills compatible" height="28"/></a>
  &nbsp;
  <a href="./CHANGELOG.md"><img src="https://img.shields.io/badge/changelog-keep%20a%20changelog-orange" alt="Changelog" height="28"/></a>
</p>

<p align="center"><sub><a href="#install">Install</a> · <a href="#what-it-covers">What it covers</a> · <a href="#templates">Templates</a> · <a href="#deploy">Deploy</a> · <a href="#compatibility">Compatibility</a> · <a href="#faq">FAQ</a> · <a href="#license">License</a></sub></p>

## What it is

A directory-bundle **Agent Skill** that turns a one-line "release this" prompt into a coordinated publish across every channel that matters: package registry (npm / crates.io / PyPI), git remotes (GitHub + Gitee), marketplace listings (DSH + Anthropic + Codex), repo RP fields, bilingual README, and git tags. One release leaves every silo in agreement, so you never ship a v0.4.27 with no tag and a stale changelog again.

## Why

Every channel is an independent silo. npm knows a version, git knows a commit, marketplaces scan topics: skipping one step leaves them disagreeing, and backfilling later is error-prone. publish-kit hardcodes the SOP + 10 copy-paste templates so the agent handles the bookkeeping, not you.

## Install

```bash
npx skills add https://github.com/EternalNight996/publish-kit
```

Installs into `~/.agents/skills/` on every host that consumes the directory-bundle format (DSH, Claude Code, Codex CLI, Gemini CLI, Cursor). Single-skill install:

```bash
npx skills add https://github.com/EternalNight996/publish-kit --skill "publish-kit"
```

Other install paths (manual copy, project-scoped, host-specific managers like `dsh-agent-skills`) are documented in [`.agents/skills/publish-kit/INSTALL.md`](./.agents/skills/publish-kit/INSTALL.md).

## What it covers

- **npm release SOP** — version bump → test → publish → tag → push → RP fields, with the registry, token, scope, files-whitelist, and peer-dependency traps.
- **DSH plugin marketplace** — full matrix for the four DSH marketplaces (auto topic-scan, awesome PR, dsh-market Issue, dsh-plugin-marketplace static validator) plus the `dsh.marketplace` metadata schema.
- **npm slimming** — separate runtime assets from showcase media so the tarball drops from 10 MB to ~50 KB without breaking README rendering (DSH `assets/screen` distinction preserved).
- **git tag SOP** — the workflow that fixes the "40 versions with zero tags" mistake: resolve hash from `git log`, verify subject, push; never guess with `commit~N`.
- **Bilingual README** — zh/en file split, badge row, GIF under 10 MB, ffmpeg compression recipe.
- **Dual-remote push** — GitHub + Gitee via SSH with one-shot `publish.bat` (full-width-punctuation trap and stale-remote trap documented).
- **cargo / PyPI baseline** — standard registry flow for each, marked honestly as not yet battle-tested locally.
- **PyInstaller exe build** — the `_MEIPASS` path trap that erases user output, the `base_library.zip` stale-cache trap, and the bat ASCII-punctuation trap.
- **GitHub Actions release** — tag + npm publish + GitHub Release in one workflow, with `npm version` rewiring `package.json`.

Full dense facts: [`.agents/skills/publish-kit/REFERENCE.md`](./.agents/skills/publish-kit/REFERENCE.md).

## Templates

Ten copy-paste skeletons (each with "when to use" + knobs), one per release track:

| # | Template | Track |
| --- | --- | --- |
| A | `package.json` (DSH plugin) | npm + DSH marketplace |
| B | `data/plugins/<owner>__<repo>.yml` | awesome-dsh-plugin PR |
| C | Issue body | dsh-market submission |
| D | `publish.bat` | GitHub + Gitee dual-remote |
| E | Bilingual README skeleton | landing page for npm + GitHub |
| F | `PUBLISH.md` | git-install three-knob config for DSH plugins |
| G | GitHub Actions release workflow | tag + publish + GitHub Release |
| H | `Cargo.toml` | crates.io |
| I | `pyproject.toml` | PyPI |
| J | PyInstaller build script | standalone exe |

See [`.agents/skills/publish-kit/TEMPLATE.md`](./.agents/skills/publish-kit/TEMPLATE.md) for all ten.

## Deploy

publish-kit is a skill bundle, not a DSH plugin. Distribution follows the same channels as any open-source skill bundle:

- **GitHub + Gitee** as the source of truth (`git push` both remotes on every release).
- **`npx skills add <url>`** — Vercel CLI routes to `~/.agents/skills/` on every supported host.
- **`awesome-dsh-plugin`** — open a PR adding the entry under category `tooling`.
- **`dsh-market`** — file an Issue listing the bundle with topic `dsh-skill`.
- **DSH marketplaces** — repo topics `dsh-skill`, `agent-skills`, `publishing`, `npm`, `release` make the auto-scanners pick it up.

DSH-specific deployment (six discovery roots, watch semantics, rank ordering) lives in [`.agents/skills/publish-kit/DSH-DEPLOY.md`](./.agents/skills/publish-kit/DSH-DEPLOY.md).

## Compatibility

| Host | Skill directory | Watch? | Restart on install? |
| --- | --- | --- | --- |
| DeepSeek Harness (DSH) | `<root>/.agents/skills/`, `~/.agents/skills/`, ... | yes | no |
| Claude Code | `~/.claude/skills/`, `<root>/.claude/skills/` | yes | no |
| Codex CLI | `~/.codex/skills/` | yes | no |
| Gemini CLI | `~/.gemini/skills/` | yes | no |
| Cursor | `<root>/.cursor/skills/` | partial | depends |
| Windsurf / VS Code Copilot | best-effort | — | — |

Frontmatter uses only the universally-supported `name` + `description` fields. Full matrix and body-format limits in [`.agents/skills/publish-kit/COMPATIBILITY.md`](./.agents/skills/publish-kit/COMPATIBILITY.md).

## One-shot release script

For a fully automated release that follows this playbook end-to-end, see [`scripts/bootstrap-release.ps1`](./scripts/bootstrap-release.ps1) (PowerShell) and [`scripts/bootstrap-release.sh`](./scripts/bootstrap-release.sh) (bash). They run the six-step flow: bump version, test+build, commit, npm publish (with throwaway token), tag + push both remotes, GitHub RP fields. Pass `patch`, `minor`, or `major` as the argument.

## How the skill gets triggered

The agent reads the `description` frontmatter field on every catalog refresh. publish-kit's description carries the concrete trigger branches:

> Use when the user wants to publish, release, deploy, ship, cut a version, bump a version, tag a release, write or restructure a README, slim an npm package, push to GitHub and Gitee, submit a plugin to a marketplace, run cargo publish, publish to PyPI, build a PyInstaller exe, draft a changelog, or set up GitHub Releases.

Once loaded, the skill workflow classifies the release into one of five tracks (npm / DSH plugin / cargo / PyPI / git-only), runs the per-track SOP, and applies the matching template from `TEMPLATE.md`.

## FAQ

**Why a directory bundle and not a single `SKILL.md`?** Because the dense release SOP exceeds 100 lines (house format) and the templates need to be copy-paste friendly. Splitting into `REFERENCE.md` + `TEMPLATE.md` + `INSTALL.md` keeps `SKILL.md` short and lets each host render Markdown files independently.

**Why publish as a skill and not as an npm package?** Both work. As an npm package you also get a `dsh plugin --profile web add` install path (DSH users reach it via the plugin market). As a skill bundle you get `npx skills add` on every host including DSH. The two are complementary; the optional npm-wrapper pattern is documented in `DSH-DEPLOY.md`.

**Does the agent need the skill loaded to read the templates?** Yes — the templates are part of the bundle. Loading `publish-kit` makes `TEMPLATE.md` available to the agent's tool surface alongside `SKILL.md`.

**What does "publish-kit" not cover?** Host-specific runtime debugging, package internals design, language-specific lint/test setup, monorepo versioning strategies. It covers the release boundary only.

**How do I report a release trap that publish-kit missed?** Open an Issue; the bundle gets a tag bump on every accepted addition.

## License

[MIT](./LICENSE) — Copyright (c) 2026 EternalNight996.
