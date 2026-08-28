# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
