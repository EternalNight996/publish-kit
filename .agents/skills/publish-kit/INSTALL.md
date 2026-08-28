# Install publish-kit

Four install paths, ordered from easiest to most explicit. Pick whichever fits your workflow; the skill file layout is the same in every case.

## 1. One-liner (cross-platform, recommended)

```bash
npx skills add https://github.com/EternalNight996/publish-kit
```

Installs to the right directory for whichever host you use (DSH, Claude Code, Codex CLI, Cursor, Gemini CLI). The CLI routes to `~/.agents/skills/` by default; pass `--skill "publish-kit"` to install only this skill, `--user` or `--project` to override scope.

Verify after install:

```bash
ls ~/.agents/skills/publish-kit/SKILL.md   # DSH / Codex / Gemini
ls ~/.claude/skills/publish-kit/SKILL.md    # Claude Code
```

## 2. DSH native (no install tool)

DSH's built-in skill-filesystem watches two directories at the user level and two at the project level:

| Scope | Path | When to use |
| --- | --- | --- |
| User (global) | `~/.agents/skills/publish-kit/` | you want it in every project |
| User (DSH canonical) | `~/.dsh/skills/publish-kit/` | DSH-only host, no other agent |
| Project | `<repo>/.agents/skills/publish-kit/` | pin to one repo (committable) |
| Project (DSH canonical) | `<repo>/.dsh/skills/publish-kit/` | same, DSH-only |

Pick one and copy the directory in:

```bash
# user-global (recommended for personal use)
git clone https://github.com/EternalNight996/publish-kit /tmp/publish-kit
cp -r /tmp/publish-kit/.agents/skills/publish-kit ~/.agents/skills/

# PowerShell equivalent on Windows
git clone https://github.com/EternalNight996/publish-kit $env:TEMP\\publish-kit
Copy-Item -Recurse $env:TEMP\\publish-kit\\.agents\\skills\\publish-kit $HOME\\.agents\\skills\\
```

DSH picks up the new skill on its next scan; no restart needed (skills are file-watched; plugins are not).

## 3. With the dsh-agent-skills plugin (DSH-side manager)

If you already run the [`dsh-agent-skills`](https://github.com/minivv/dsh-agent-skills) DSH plugin, it scans five directories and lets you toggle skills from the settings UI:

- `~/.agents/skills/` (DSH native)
- `~/.claude/skills/` (Claude Code mirror)
- `~/.codex/skills/` (Codex CLI)
- `~/.config/opencode/skills/`
- `~/.gemini/skills/`

Drop `publish-kit/` into any of those and DSH's settings page will list it. Use this path when you already maintain Claude Code or Codex skill libraries and want them to surface in DSH.

## 4. Manual (no tooling)

```bash
mkdir -p ~/.agents/skills/publish-kit
curl -L https://raw.githubusercontent.com/EternalNight996/publish-kit/main/.agents/skills/publish-kit/SKILL.md \\
  -o ~/.agents/skills/publish-kit/SKILL.md
curl -L https://raw.githubusercontent.com/EternalNight996/publish-kit/main/.agents/skills/publish-kit/REFERENCE.md \\
  -o ~/.agents/skills/publish-kit/REFERENCE.md
# repeat for INSTALL.md / DSH-DEPLOY.md / COMPATIBILITY.md
```

Use this when you cannot run npx or git (corporate proxies, restricted devices). All four files are required for the skill to function.

## Verify the skill is live

After any install path, confirm:

- The skill appears in your host's skill catalog (DSH: skill catalog refresh; Claude Code: `/skills`; Codex CLI: `codex skills list`).
- The catalog description matches the package's frontmatter (one self-test: ask the agent "what is the publish-kit skill for?" and check the answer mirrors the description).
- `SKILL.md` is under 100 lines; longer belongs in `REFERENCE.md`.

## Update

```bash
# one-liner path
npx skills add https://github.com/EternalNight996/publish-kit --update

# git path
cd ~/.agents/skills/publish-kit   # or wherever you cloned
git pull
```

## Uninstall

Delete the directory you installed into. No registry to deregister, no host restart required (DSH removes the skill on the next file-watch event).
