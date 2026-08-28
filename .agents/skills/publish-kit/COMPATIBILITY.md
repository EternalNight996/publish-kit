# Compatibility Matrix

The skill targets every host that consumes the directory-bundle skill format (a folder with SKILL.md and optional reference files). Tested hosts and their conventions:

| Host | Skill directory | File-watch? | Restart on install? | Notes |
| --- | --- | --- | --- | --- |
| DeepSeek Harness (DSH) | <root>/.agents/skills/, <root>/.dsh/skills/, ~/.agents/skills/, ~/.dsh/skills/ | yes | no | built-in dsh-skill-filesystem provider |
| Claude Code | ~/.claude/skills/, <root>/.claude/skills/ | yes | no | same directory shape as DSH user-agents |
| Codex CLI | ~/.codex/skills/, <root>/.codex/skills/ | yes | no | mirrored layout |
| Gemini CLI | ~/.gemini/skills/, <root>/.gemini/skills/ | yes | no | mirrored layout |
| OpenCode | ~/.config/opencode/skills/ | yes | no | config dir, not home dotdir |
| Cursor | <root>/.cursor/skills/ | partial | depends on Cursor version | some Cursor builds scan .agents/skills/ as a fallback |
| Windsurf | <root>/.windsurf/skills/ | unknown | depends on version | treat as best-effort |
| VS Code Copilot | .github/copilot-instructions.md (instructions only, not full skill bundle) | no | n/a | partial coverage; use for repo-local hints |

For hosts not listed, the vercel-labs npx skills add CLI provides best-effort routing to .agents/skills/ (which DSH, Claude Code, Codex, Gemini all read).

## Frontmatter fields consumed

| Field | Required? | Used by |
| --- | --- | --- |
| name | yes | all hosts (skill identifier; kebab-case) |
| description | yes (model-invoked) | DSH, Claude Code, Codex, Gemini (skill catalog pointer) |
| disable-model-invocation | optional | Claude Code; true makes it user-invoked only |
| argument-hint | optional | Claude Code slash-command display |
| user-invocable | optional | Codex CLI display |
| version | optional | some hosts surface it; not required |
| author, license, keywords | optional | ignored by host runtime, read by package tools |

publish-kit uses only the universally-supported name + description fields. Do not add host-specific keys unless you are sure every target host ignores them gracefully.

## Body format

- CommonMark Markdown; all hosts render the same.
- Headings (#, ##, ###), code fences, tables, lists: supported everywhere.
- Mermaid diagrams: render on DSH and Claude Code, NOT on Cursor/Windsurf/Copilot. Offer a static-table fallback when targeting mixed audiences.
- Relative links ([INSTALL.md](INSTALL.md)) resolve only within the skill bundle; one-level deep only (no cross-skill references).
- No external CSS, no JS, no iframe content.

## Limits

- SKILL.md should stay under 100 lines (DSH convention; other hosts do not enforce). Dense facts go in REFERENCE.md; copy-paste snippets in TEMPLATE.md; cross-platform install paths in INSTALL.md; host-specific notes in <HOST>-DEPLOY.md.
- No time-sensitive claims in body content (e.g. "npm registry requires X today"). State the rule; let the user verify.
- No duplicated troubleshooting blocks across files. One canonical source per fix; cross-link from sibling files.

## File layout this skill ships

```text
publish-kit/
  SKILL.md              # main entry, <100 lines, frontmatter + workflow + checklist
  REFERENCE.md          # dense facts: marketplace table, semver, slimming, git tag SOP, troubleshooting
  TEMPLATE.md           # copy-paste templates: package.json, README, publish.bat, marketplace yml, GitHub Actions
  INSTALL.md            # cross-platform install paths
  DSH-DEPLOY.md         # DSH-specific deployment guide
  COMPATIBILITY.md      # platform + frontmatter matrix (this file)
```

Auxiliary directories (scripts/, assets/, examples/) are permitted but should not be required for the skill to work.
