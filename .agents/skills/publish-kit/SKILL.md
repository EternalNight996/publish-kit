---
name: publish-kit
description: 发布工具箱，覆盖 npm / GitHub / Gitee / DSH 插件市场 / cargo crates.io / PyPI 多渠道发布，发布分级（alpha / beta / rc / 正式版 / 补丁）与业主审批闸门，README 双语排版设计，git tag 发版 SOP，以及 npm 包瘦身。Use when the user wants to publish or release a package/plugin, choose or apply a release grade (alpha / beta / rc / release / patch), get approval before shipping a stable version, submit to a marketplace, bump a version, cut git tags, write or restructure a README, slim an npm package, or push to GitHub/Gitee remotes.
---

# Publish Kit

One release must leave every channel in agreement: package registry version, git tag, both git remotes, marketplace listing, repo RP fields, and README. Ship all of them or none.

## Grade gate (owner rule — read before anything else)

`latest` carries **only** Release and Patch. Alpha / beta / rc go to their own dist-tag and a GitHub Pre-release.

- **A stable version (Release / Patch) needs the owner's explicit approval first** — in this conversation, or via `PUBLISH_KIT_APPROVED=1` / `--approved-by=<owner>`.
- **No approval ⇒ highest allowed grade is a test build** (beta by default; alpha for internal previews).
- Unapproved + no `--grade` ⇒ the script refuses (`exit 2`) and prints the equivalent beta command. Downgrading is not authorization.
- Never hardcode `PUBLISH_KIT_APPROVED=1` in CI.

Grades, version shapes, dist-tags, command matrix and the approval table live in [RELEASE-GRADES.md](RELEASE-GRADES.md).

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
2. **Pick the grade before any command.** alpha / beta / rc are self-service; release / patch need the owner's approval (see Grade gate). Ship the lowest grade that proves the change; `./scripts/bootstrap-release.sh minor --grade beta` → npm `beta` dist-tag + GitHub Pre-release, iterate with `--grade-bump 2`, then promote with `--grade release --promote-from-beta --approved-by=<owner>`. See RELEASE-GRADES.md and REFERENCE section K.
3. Pre-flight: registry version check (`npm view <pkg> version`), lock npx versions, confirm files whitelist separates runtime assets from showcase assets.
4. README gate: bilingual split files, banner/badges/install/features/changelog order, GIF under 10 MB. For a full 19-section product README, use the distilled spec in README-DESIGN.md (section order, head template, bilingual guards, anti-patterns, fill-in skeleton, acceptance commands). See also REFERENCE section F.
5. Publish in the Quick start order; never reorder (tag before push, verify before push tags). The battle-tested stage-by-stage version with gates, the 11-file version manifest, the three-channel proof-of-success commands and the failure table is RELEASE-WORKFLOW.md.
6. Post-publish: marketplace submissions (section B), RP fields via GitHub API (section A), smoke-test install. For the discovery chain (npm keywords / GitHub topic / `screenshots.json` → nightly probe → market card), the PR/Issue target list, promo assets and release-announcement templates, use PLUGIN-CENTER-PR.md.

## Anti-patterns

WRONG: commit + push + publish, skip the tag. Later `git tag` by guessing `commit~N` creates phantom tags pointing at doc commits.
RIGHT: resolve the real hash from `git log` messages, tag it, verify the subject line, then push tags.

## Checklist

- [ ] Grade chosen and carried into the version string, CHANGELOG and Release-notes label
- [ ] Release / Patch: owner approval recorded (in-conversation, `PUBLISH_KIT_APPROVED=1`, or `--approved-by=`)
- [ ] Test grades never land on `latest`; GitHub Release flagged Pre-release
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
| [RELEASE-GRADES.md](RELEASE-GRADES.md) | choosing or enforcing a release grade: alpha / beta / rc / release / patch definitions, version + dist-tag + Release mapping, the approval gate and its four ways to pass, command matrix, promotion path, per-grade channel matrix, grade-specific failure table |
| [REFERENCE.md](REFERENCE.md) | dense facts per track: marketplace table, token handling, semver ranges, slimming, cargo/PyPI, troubleshooting |
| [EXAMPLES.md](EXAMPLES.md) | end-to-end worked transcripts: this skill's own v0.1.0 release and a full DSH plugin npm flow |
| [TEMPLATE.md](TEMPLATE.md) | copy-paste skeletons: package.json, bilingual README, marketplace yml, publish.bat, GitHub Actions release, Cargo.toml, pyproject.toml |
| [RELEASE-WORKFLOW.md](RELEASE-WORKFLOW.md) | shipping a real release: 12 ordered stages with commands, hard gates and their error strings, the 11-file version manifest + drift check, three-channel proof-of-success, failure-mode table, release-notes extraction rules |
| [README-DESIGN.md](README-DESIGN.md) | writing or restructuring a product README: 19-section order with length budgets, head/badge template, bilingual split rules + alignment guard, anti-patterns, fill-in skeleton, acceptance commands |
| [PLUGIN-CENTER-PR.md](PLUGIN-CENTER-PR.md) | getting listed and seen: 7-link discovery chain, PR/Issue target list with required fields, promo asset specs, announcement templates + title patterns, five-dimension scoring levers, channel table, red lines |
| [INSTALL.md](INSTALL.md) | install this skill into DSH, Claude Code, Codex, Gemini, or Cursor |
| [DSH-DEPLOY.md](DSH-DEPLOY.md) | DSH-specific deployment: where the runtime finds skills, watch semantics, ranks, distribution channels |
| [COMPATIBILITY.md](COMPATIBILITY.md) | platform + frontmatter matrix, body-format limits |

Complementary skills (install separately, not part of this bundle): `git-guardrails-claude-code` for blocking destructive git commands, `find-skills` for locating more skills, `setup-pre-commit` for repo-local lint gates, `remember` for capturing release lessons back into agentmemory.
