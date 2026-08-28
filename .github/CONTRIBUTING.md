# Contributing to publish-kit

Thanks for considering a contribution. publish-kit is a directory-bundle skill + ( npm-installable CLI, so contributions range from a one-line copy fix in a `SKILL.md` to a full cross-platform release script.

## Ground rules

- Keep `SKILL.md` under **100 lines**. Dense facts go in `REFERENCE.md`; copy-paste skeletons in `TEMPLATE.md`; cross-platform install paths in `INSTALL.md`; host-specific notes in `<HOST>-DEPLOY.md`.
- The `description` field on `SKILL.md` must include a `Use when ...` clause with one trigger per branch.
- House style (no emojis in body, no em-dashes, no external product names, no time-sensitive claims). See [`write-agentmemory-skill` skill](./.agents/skills/write-agentmemory-skill) for the full format.
- English `README.md` is the source of truth. `README.zh.md` is the Chinese translation. When you change one, change the other.
- Run the release flow once on yourself before claiming a release track template works (`eat your own dogfood`).

## Where to send what

| You changed | Send to |
| --- | --- |
| Skill bundle content (any `*.md` under `.agents/skills/publish-kit/`) | PR here (this repo) |
| Top-level README / `CHANGELOG.md` / `LICENSE` | PR here |
| `package.json` / `cordis.patch.yml` / `scripts/postinstall.js` | PR here; after merge, run `npm version patch && npm publish` |
| Scripts (`scripts/bootstrap-release.*`, `scripts/release-exe.*`) | PR here |
| GitHub Actions workflows | PR here |
| Repo governance (this directory) | PR here |

## Local dev loop

```bash
# Clone
git clone https://github.com/EternalNight996/publish-kit
cd publish-kit

# If you change .agents/skills/publish-kit/ and want the agent to see it:
cp -r .agents/skills/publish-kit ~/.agents/skills/publish-kit   # user-global
# or: cp -r .agents/skills/publish-kit .agents/skills/publish-kit   # project-local (re-read since same dir)

# If you change scripts:
npm install -g .   # if you also changed package.json
# or just invoke directly:
./scripts/bootstrap-release.sh patch

# If you change GitHub Actions:
# validate locally with `act -j build` (optional; CI will catch issues)
```

## Testing checklist for a PR

- [ ] If you changed `SKILL.md`, verify it is still under 100 lines (`wc -l .agents/skills/publish-kit/SKILL.md`).
- [ ] If you added a template, add at least one worked example to `EXAMPLES.md`.
- [ ] If you changed `package.json`, run `npm pack --dry-run` and confirm the file list and size match expectations.
- [ ] If you added or changed a workflow, verify it parses: `gh workflow view <name>` or open the workflow file in GitHub.
- [ ] If you changed `README.md`, update `README.zh.md` in lockstep.
- [ ] If you mentioned a release SOP change, add an entry to `CHANGELOG.md` under the current version.

## Coding style (for scripts)

- `bash` scripts: `set -euo pipefail`; quote all variables; one tab indent.
- PowerShell scripts: `[CmdletBinding()]` on functions; `Set-StrictMode -Version Latest`; 4-space indent.
- Comment every non-obvious step. Inline comments preferred over block comments.

## Release flow for maintainers

This repo practices what it preaches: see `scripts/bootstrap-release.sh` for npm release and `scripts/release-exe.sh` for exe release. Maintainers:

1. Bump version in `package.json` and commit.
2. Run `scripts/bootstrap-release.sh patch` (or `minor` / `major`).
3. The script handles: npm publish, git tag, push both remotes, GitHub RP fields.
4. After release: PR to `awesome-dsh-plugin` and Issue to `dsh-market` if marketplace submission is new.

## Code of conduct

By participating you agree to maintain a respectful, constructive tone. See [`CODE_OF_CONDUCT.md`](./CODE_OF_CONDUCT.md) if present (.optional but encouraged).

## Questions?

Open an Issue with the `question` label. The maintainers respond within a few days.
