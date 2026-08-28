# DSH Deployment Guide

publish-kit is a directory-bundle skill (one folder containing SKILL.md plus optional reference files). DSH discovers it via the dsh-skill-filesystem provider, which the host injects at boot.

## How DSH finds the skill

The provider enumerates six roots on each refresh, ranked from highest to lowest priority:

| Rank | Source | Path |
| --- | --- | --- |
| 100 | project-dsh | <projectRoot>/.dsh/skills/ |
| ~150 | project-agents | <projectRoot>/.agents/skills/ |
| 400 | user-dsh | ~/.dsh/skills/ |
| ~450 | user-agents | ~/.agents/skills/ |
| (config) | custom | config.customSkillDirs array |
| (env) | bundled | DSH_BUNDLED_SKILL_DIR |

Higher rank wins when two roots expose the same skill name. Project roots always beat user roots, so a project-local publish-kit/ overrides the user-global copy for that repo. Two publish-kit/ files in different roots do NOT merge; the higher-rank one is used whole.

The project root is discovered by walking up from the current working directory until either .git/, .dsh/, or package.json is found. If none are present, project roots are skipped.

## Pick the right root

- Per-project, committable (preferred for teams): <repo>/.agents/skills/publish-kit/. Commit it; every contributor and CI gets the same release knowledge.
- Per-user, cross-project: ~/.agents/skills/publish-kit/. Personal setup, one install serves every repo.
- DSH-only host: ~/.dsh/skills/publish-kit/. Same priority as ~/.agents/skills/ for DSH purposes, but no other host will see it.

## File watching (DSH refresh semantics)

The provider runs a SkillWatchManager over the configured roots:

- New file -> next provider refresh registers the skill (no host restart).
- Edits to SKILL.md body or frontmatter -> the cached description is invalidated and the next request re-reads it.
- Renames or deletions -> skill is removed from the catalog on the next event.
- File watching is per-skill; the agent picks up changes mid-session. This is different from plugins (dsh plugin --profile web add): plugins ship a build artifact that requires a host process restart to reload.

If the description in your catalog does not update after an edit, check the host logs (~/.dsh/logs/) for filesystem-watcher events; some sandboxed environments disable file watching.

## Publishing publish-kit for DSH users

There is no DSH-specific skill marketplace; distribution follows the same channels as any other open-source skill bundle.

| Channel | Mechanism | Manual step | Notes |
| --- | --- | --- | --- |
| GitHub + Gitee | git push | yes | tag every release (v<x.y.z>); see REFERENCE.md section E |
| npx skills add <url> | Vercel CLI | none for you, user runs it | CLI writes to ~/.agents/skills/ on every host (DSH included) |
| awesome-dsh-plugin repo | PR | yes | add data/plugins/<owner>__<repo>.yml with category: tooling (or release if added); regen README via node scripts/generate-readme.mjs |
| dsh-market repo | Issue | yes | title [提交工具] publish-kit 发布工具箱; reference topic agent-skill |
| dsh-marketplace | auto-scan by topic | none | repo must carry dsh-skill topic (alongside dsh-plugin if it is also installable as a plugin) |
| dsh-find-plugin | search by topic | none | topic agent-skill |
| npm package (`@eternalnight/publish-kit`) | publish | none for the user | `@eternalnight/publish-kit` wraps `.agents/skills/publish-kit/` and exposes it as a tarball asset; `dsh plugin --profile web add @eternalnight/publish-kit` triggers the postinstall symlink into `~/.agents/skills/publish-kit/` |

The npm-wrapper pattern is the **canonical install path** for users who prefer `dsh plugin --profile web add @eternalnight/publish-kit` over `npx skills add <github-url>`. publish-kit itself uses this pattern: a `package.json` with `dsh.client.platform: "web"` + `dsh.marketplace` metadata, plus a `postinstall.js` that symlinks the bundled skills directory into the user's `~/.agents/skills/`.

## Topic taxonomy

DSH does not have a separate skill category in topic discovery. Repos that publish skill bundles should carry at least:

- dsh-skill (skill bundle present in .agents/skills/ or skills/)
- agent-skills (cross-platform, also valid in Anthropic/Codex ecosystems)
- publishing, release, npm, cargo, pypi as relevant

For tooling that is BOTH a skill bundle and a DSH plugin, add dsh-plugin so the dsh-marketplace scanners pick it up.

## RP fields for the skill-bundle repo

Same as a DSH plugin: repo Description and Topics via GitHub API (PATCH for description, PUT /topics for topics - they are separate endpoints, mixing topics into PATCH returns 400). Reference: REFERENCE.md section A.

## Skill bundle inclusion standard (the canonical checklist)

For a skill bundle to appear on every host that consumes it, the bundle must satisfy the conventions below. This is the same checklist publish-kit itself follows; copy it for your own bundles.

### File layout (required)

```
<your-skill-bundle>/
  README.md                # English landing page
  README.zh.md             # Chinese mirror (optional but recommended for reach)
  LICENSE                  # MIT recommended
  CHANGELOG.md             # Keep a Changelog format
  .gitignore
  .claude-plugin/
    plugin.json            # Vercel CLI manifest (npx skills add discovery)
    marketplace.json       # Vercel CLI marketplace
  assets/
    /readme-banner.{svg,png,webp}  # top-of-README visual hook
    /social-preview.png            # 1280x640 GitHub social preview
  .agents/skills/<your-skill>/
    SKILL.md               # <100 lines, model-invoked, frontmatter name+description
    REFERENCE.md           # dense facts
    TEMPLATE.md            # copy-paste skeletons (optional)
    INSTALL.md             # cross-platform install paths
    <HOST>-DEPLOY.md       # host-specific notes (optional, per host)
    EXAMPLES.md            # worked transcripts (optional)
```

### Frontmatter contract (every host)

```yaml
---
name: your-skill-name            # kebab-case, lowercase, unique
description: <capability sentence>. Use when <trigger branch 1>, <trigger branch 2>, ..., or <trigger branch N>.
---
```

Rules:
- Two sentences total. First states the capability. Second starts with `Use when` and lists concrete trigger branches.
- One trigger per branch. Collapse synonyms.
- Front-load the leading word (the pointer does its triggering work in the description).
- Under 1024 characters.

### Repo-level requirements

| Requirement | Why |
| --- | --- |
| Public repo | All hosts require it |
| MIT license (or compatible permissive) | Removes legal ambiguity for users |
| Topics: at minimum `dsh-skill` and `agent-skills` (or `dsh-plugin` if shipping a cordis plugin) | Auto-discovery scanners read topics |
| Description: one line, English, with concrete keywords | Search results and SEO |
| Social preview PNG uploaded (1280x640) | Largest click-rate lever when URL is shared |
| Tagged releases (`v<x.y.z>`) | Versions must be queryable |
| `npx skills add <repo-url>` works out of the box | Vercel CLI reads `.claude-plugin/plugin.json` |

### Marketplace-by-marketplace detailed steps

**awesome-dsh-plugin (PR-based, category=skill):**
1. Fork the repo.
2. Create `data/plugins/<owner>__<repo>.yml` (double underscore, no .yml on owner/repo).
3. UTF-8 without BOM (js-yaml fails on BOM).
4. After adding: `node scripts/generate-readme.mjs` to regenerate the curated README.
5. Open PR; reference an existing merged PR for tone.

**dsh-market (Issue-based):**
1. Open issue with title `[提交工具] <name>`.
2. Reference topic `dsh-skill`.
3. List features (bullet list) and one-line purpose.

**dsh-marketplace / dsh-find-plugin (auto-scan by topic):**
1. Set repo topic `dsh-skill` (or `dsh-plugin` for cordis).
2. Wait for the next scan cycle.
3. No manual step.

**dsh-plugin-marketplace (cordis plugins only):**
1. Set repo topic `dsh-plugin`.
2. Add `dsh.marketplace` block to `package.json`:
   ```json
   "dsh": { "marketplace": { "profiles": ["web"], "requiresBuildApproval": false, "requiresRestart": true, "manualSteps": false } }
   ```
3. Wait for the 2h scan cycle.

**Vercel CLI `npx skills add <repo-url>`:**
1. Add `.claude-plugin/plugin.json` with `name`, `description`, `version`, `repository`.
2. Optionally add `.claude-plugin/marketplace.json` for marketplace indexing.
3. No further setup; the CLI reads the manifest and writes to `~/.agents/skills/`.

**npm wrapper (for other skill authors who want `dsh plugin --profile web add <their-skill>`):**
1. Create an npm package whose `files` includes `skills/<your-skill>/`.
2. Add `dsh.client.platform: "web"` + `dsh.bundle.patch: "./cordis.patch.yml"` to `package.json`.
3. Add `scripts.prepublishOnly` that runs a build step to copy the skills directory into a staging location.
4. Add `scripts.postinstall` (or a plugin init hook) that symlinks the staged skills directory to `~/.agents/skills/<your-skill>/`.
5. Publish to npm with explicit `--registry=https://registry.npmjs.org/`.

### Topic checklist for a skill bundle

Minimum required topics:
- `dsh-skill`
- `agent-skills`

Domain-specific topics (pick all that apply):
- `publishing`, `release`, `npm`, `cargo`, `pypi`, `docker`, `homebrew`, `nuget`, `maven`, `rubygems`, etc.

Optional:
- `awesome-dsh-plugin` (only if you have an entry merged there)

### What disqualifies a bundle from inclusion

- Private repo.
- No frontmatter or no `Use when` clause.
- SKILL.md over 100 lines (move dense content to `REFERENCE.md`).
- No license file.
- No tag on a release commit (auto-scanners cannot map versions).
- Token committed in the repo (immediate security-flag review).

### What boosts inclusion

- Bilingual README (en + zh) — reach doubles in the DSH ecosystem.
- Working CI (GitHub Actions release workflow).
- `EXAMPLES.md` with at least one full worked transcript.
- A banner + social-preview image.
- One PR to awesome-dsh-plugin + one Issue to dsh-market on the same day as the v0.1.0 release (signals "the author takes discovery seriously").
