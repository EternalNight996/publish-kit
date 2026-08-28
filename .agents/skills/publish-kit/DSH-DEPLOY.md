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
| npm (wrapper package) | publish | yes | package wraps skills/publish-kit/ and exposes the directory as an asset; users add it via dsh plugin --profile web add <pkg> and symlink the skill to ~/.agents/skills/publish-kit/ |

The optional npm-wrapper pattern is the only path that turns a skill into a DSH plugin; it requires a package.json with dsh.client.platform: "web" and a script that copies the bundled skills/ directory into the user's ~/.agents/skills/.

## Topic taxonomy

DSH does not have a separate skill category in topic discovery. Repos that publish skill bundles should carry at least:

- dsh-skill (skill bundle present in .agents/skills/ or skills/)
- agent-skills (cross-platform, also valid in Anthropic/Codex ecosystems)
- publishing, release, npm, cargo, pypi as relevant

For tooling that is BOTH a skill bundle and a DSH plugin, add dsh-plugin so the dsh-marketplace scanners pick it up.

## RP fields for the skill-bundle repo

Same as a DSH plugin: repo Description and Topics via GitHub API (PATCH for description, PUT /topics for topics - they are separate endpoints, mixing topics into PATCH returns 400). Reference: REFERENCE.md section A.
