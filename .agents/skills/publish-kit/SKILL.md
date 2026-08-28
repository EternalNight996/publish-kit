---
name: publish-kit
description: 发布工具箱，覆盖 npm / GitHub / Gitee / DSH 插件市场 / cargo crates.io / PyPI 多渠道发布，README 双语排版设计，git tag 发版 SOP，以及 npm 包瘦身。Use when the user wants to publish or release a package/plugin, submit to a marketplace, bump a version, cut git tags, write or restructure a README, slim an npm package, or push to GitHub/Gitee remotes.
---

# Publish Kit

One release must leave every channel in agreement: package registry version, git tag, both git remotes, marketplace listing, repo RP fields, and README. Ship all of them or none.

## Quick start

A standard release for an npm package (DSH plugin or not):

1. Bump version in package.json; commit with the version number in the message.
2. Build (`prepublishOnly`) and run tests.
3. `npm publish --registry=https://registry.npmjs.org/` with a throwaway token in `.npmrc`, then delete `.npmrc`.
4. `git tag v<x.y.z>` on that exact commit, verify with `git show v<x.y.z> --format=%s --no-patch`, then `git push origin main --tags` and `git push gitee main --tags`.
5. Update repo Description + Topics (topic `dsh-plugin` for plugins), submit PR/Issue to marketplaces if applicable.

## Why

Every channel is an independent silo. npm knows a version, git knows a commit, marketplaces scan topics: skipping one step leaves them disagreeing, and backfilling later is error-prone (40 versions had to be retagged by hand once).

## Workflow

1. Classify the release: npm package, DSH plugin, git-only project, cargo crate, PyPI/exe artifact. See REFERENCE for per-track steps.
2. Pre-flight: registry version check (`npm view <pkg> version`), lock npx versions, confirm files whitelist separates runtime assets from showcase assets.
3. README gate: bilingual split files, banner/badges/install/features/changelog order, GIF under 10 MB. See REFERENCE section F.
4. Publish in the Quick start order; never reorder (tag before push, verify before push tags).
5. Post-publish: marketplace submissions (section B), RP fields via GitHub API (section A), smoke-test install.

## Anti-patterns

WRONG: commit + push + publish, skip the tag. Later `git tag` by guessing `commit~N` creates phantom tags pointing at doc commits.
RIGHT: resolve the real hash from `git log` messages, tag it, verify the subject line, then push tags.

## Checklist

- [ ] Version bumped; commit message carries the version
- [ ] `npm pack --dry-run` file list and size reviewed
- [ ] Published with explicit `--registry=https://registry.npmjs.org/`; token file deleted
- [ ] Tag created on the exact commit and verified before pushing
- [ ] Both remotes (origin GitHub, gitee) pushed including tags
- [ ] Repo Description + Topics set (independent topics endpoint)
- [ ] README: bilingual files, language switch links, GIF under 10 MB
- [ ] Marketplace requirements met (topic `dsh-plugin`, `dsh.marketplace` metadata, PR/Issue where manual)

## See also

| File | Use when you need |
| --- | --- |
| [REFERENCE.md](REFERENCE.md) | dense facts per track: marketplace table, token handling, semver ranges, slimming, cargo/PyPI, troubleshooting |
| [TEMPLATE.md](TEMPLATE.md) | copy-paste skeletons: package.json, bilingual README, marketplace yml, publish.bat, GitHub Actions release, Cargo.toml, pyproject.toml |
| [INSTALL.md](INSTALL.md) | install this skill into DSH, Claude Code, Codex, Gemini, or Cursor |
| [DSH-DEPLOY.md](DSH-DEPLOY.md) | DSH-specific deployment: where the runtime finds skills, watch semantics, ranks, distribution channels |
| [COMPATIBILITY.md](COMPATIBILITY.md) | platform + frontmatter matrix, body-format limits |

Complementary skills (install separately, not part of this bundle): `git-guardrails-claude-code` for blocking destructive git commands, `find-skills` for locating more skills, `setup-pre-commit` for repo-local lint gates, `remember` for capturing release lessons back into agentmemory.
