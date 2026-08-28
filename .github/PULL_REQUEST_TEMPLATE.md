## What does this PR do?

<!-- One-paragraph summary. Skip the marketing speak; explain what changes. -->

## Which track does this affect?

<!-- Check all that apply -->

- [ ] Skill bundle (`SKILL.md` / `REFERENCE.md` / `TEMPLATE.md` / `INSTALL.md` / `DSH-DEPLOY.md` / `COMPATIBILITY.md` / `EXAMPLES.md`)
- [ ] npm package (`package.json` / `cordis.patch.yml` / `scripts/postinstall.js`)
- [ ] Scripts (`scripts/bootstrap-release.*` / `scripts/release-exe.*`)
- [ ] GitHub Actions workflow
- [ ] Documentation (top-level `README.md` / `README.zh.md` / `CHANGELOG.md`)
- [ ] Repo governance (`.github/` directory)

## House-format checklist

- [ ] `SKILL.md` is under 100 lines
- [ ] `SKILL.md` frontmatter has `name` + `description`; description includes a `Use when ...` clause with one trigger per branch
- [ ] `name` is kebab-case lowercase
- [ ] Dense facts moved to `REFERENCE.md` rather than appended to `SKILL.md`
- [ ] `README.md` and `README.zh.md` are mirrors (English and Chinese)
- [ ] No duplicated troubleshooting across files
- [ ] No external / competitor product names in the body
- [ ] No emojis in prose (allowed in section H1 / H2 headings only)
- [ ] No em-dashes in prose

## Release flow checklist (if your PR changes the release behavior)

- [ ] If `package.json# version` bumped: tag created (`v<x.y.z>`) and pushed to both `origin` and `gitee`
- [ ] If marketplace submission changed: PR sent to `awesome-dsh-plugin` and Issue sent to `dsh-market`
- [ ] If GitHub RP fields changed: `gh api -X PATCH ... -f description=...` and `gh api -X PUT .../topics --input ...`
- [ ] If a new marketplace channel added: update both `README.md` Discovery table and `DSH-DEPLOY.md` inclusion matrix

## Test evidence

<!-- Commands actually run + their output. "Looks good" is not evidence. -->

```
$ <command>
<output>
```

## Related issues / PRs

<!-- Link with #123 or full URL. Use Closes #123 if this resolves an issue. -->
