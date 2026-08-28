# Security policy

publish-kit is a documentation + script bundle, not a runtime that processes untrusted input. The security surface is therefore small — it mostly reduces to two things:

1. **Token handling in the release scripts.** `scripts/bootstrap-release.{ps1,sh}` writes an npm auth token to `.npmrc.publish` and deletes it in a `finally` / `trap` block. If you fork the script and remove the cleanup, tokens can leak.
2. **Anything you embed in a release script that processes the git history.** If you script on top of publish-kit and that script reads `git log` or `git show`, the output is trusted local content — but if the script is then shared, the embedded content is part of the distribution.

## Reporting a vulnerability

Email `EternalNight996@users.noreply.github.com` with a description of the issue and a reproducer. Include the publish version and the host (DSH / Claude Code / etc.) if relevant. Allow up to 7 days for an initial response; fix timelines depend on severity.

For non-critical issues, open a public Issue with the `bug` label. Critical issues (token leakage, command injection in a release script) should be reported privately first.

## Supported versions

Only the latest minor of the latest major is actively supported. Older versions receive security patches only for critical issues. See the Roadmap in the top-level `README.md` for current release status.

## What is NOT in scope

- Bugs in the upstream registries (npm, crates.io, PyPI). Report those to the respective maintainers.
- Bugs in third-party templates. If a template points to a specific GitHub Action version, file the issue upstream and update the pinned SHA in publish-kit.
- Bugs in the host agents (DSH, Claude Code, etc.). Report those to the agent maintainers.

## Disclosure timeline

1. Day 0: you email the maintainer.
2. Day 1-7: maintainer confirms, drafts a fix, opens a private PR.
3. Day 7-30: fix lands in a patch release; advisory published in `CHANGELOG.md` and (if severe) GitHub Security Advisories.
4. Day 30+: public disclosure if not already done.
