# Publish Kit Templates

Copy-paste skeletons, organized by release track. Every template is annotated with when to use and key knobs to inspect before publishing.

## A. DSH plugin package.json

When: any DSH plugin (cordis plugin that runs inside the host) that you intend to ship to npm + the dsh-* marketplaces.

```json
{
  "name": "@<user>/<pkg>",
  "version": "0.1.0",
  "description": "<one-line English purpose>",
  "keywords": ["dsh-plugin", "deepseek-harness", "dsh"],
  "repository": { "type": "git", "url": "git+https://github.com/<user>/<repo>.git" },
  "homepage": "https://github.com/<user>/<repo>#readme",
  "author": "<user>",
  "license": "MIT",
  "publishConfig": { "registry": "https://registry.npmjs.org/" },
  "files": ["index.js", "lib", "cordis.patch.yml", "README.md", "README.en.md", "LICENSE"],
  "scripts": { "prepublishOnly": "node build.mjs" },
  "peerDependencies": { "@deepseek-ai/dsh": ">=0.1.0-rc.2 <0.2.0", "cordis": "^4.0.1" },
  "dsh": {
    "client": { "platform": "web" },
    "bundle": { "patch": "./cordis.patch.yml" },
    "marketplace": { "profiles": ["web"], "requiresBuildApproval": false, "requiresRestart": true, "manualSteps": false }
  }
}
```

Knobs: name taken? Scope it and add --access public. files whitelist separates runtime from showcase assets. peerDependencies widest safe range. dsh.marketplace.profiles required for YELEBAI.

## B. awesome-dsh-plugin entry

When: adding a plugin to the awesome-dsh-plugin curated list (PR-based).

Filename: data/plugins/<owner>__<repo>.yml (double underscore).

```yaml
url: https://github.com/<owner>/<repo>
name: <owner>/<repo>
category: <memory|tooling|theme>
description:
  en: "<one-line English purpose>"
  zh: "<one-line Chinese purpose>"
```

Knobs: UTF-8 without BOM (js-yaml fails on BOM). category from known enum. After adding: node scripts/generate-readme.mjs to regen.

## C. dsh-market Issue body

When: filing an Issue on 2BingLing/dsh-market to manually list the plugin.

```markdown
## 插件信息
- GitHub 仓库地址：https://github.com/<owner>/<repo>
- 插件类型：cordis-plugin
- 一句话简介：<one-line>
- 是否已打 dsh-plugin 相关 topic：是

## 补充说明
- 独特功能：<bullets>
- 演示：README 顶部 gif + 截图
- npm 已发布 <pkg>@<version>
```

## D. publish.bat (GitHub + Gitee SSH)

When: a non-DSH project that you want to push to both GitHub and Gitee with one click. Designed for PowerShell.

```bat
@echo off
setlocal

set GH=git@github.com:YOUR_USER/REPO.git
set GITEE=git@gitee.com:YOUR_USER/REPO.git
set REPO=REPO

if not exist "%USERPROFILE%\.ssh\id_ed25519" (
  echo Generating SSH key...
  ssh-keygen -t ed25519 -N "" -f "%USERPROFILE%\.ssh\id_ed25519"
  echo.
  echo Add this public key to GitHub and Gitee:
  type "%USERPROFILE%\.ssh\id_ed25519.pub"
  echo.
  pause
)

if not exist .git (
  git init -b main
)

git remote remove origin 2>nul
git remote add origin %GH%
git remote remove gitee 2>nul
git remote add gitee %GITEE%

git add -A
git commit -m "chore: publish %REPO%" || echo Nothing to commit

git push -u origin main
git push -u gitee main

echo.
echo Done. Pushed to %GH% and %GITEE%.
endlocal
```

Knobs: ALL punctuation ASCII (cmd parses full-width punctuation as commands). Replace YOUR_USER/REPO at top. .gitignore should exclude build/, dist/, out/, logs/, *.spec, config.json, crash.log.

## E. Bilingual README skeleton

When: any package that you want to publish with a polished landing page on npm + GitHub.

Filename split: README.md (zh) + README.en.md (en). Both go in the npm files whitelist.

```markdown
<p align="center">
  <img src="https://raw.githubusercontent.com/<owner>/<repo>/main/assets/screen/banner.gif" width="640" alt="banner"/>
</p>

<h1 align="center"><pkg></h1>
<p align="center"><em><tagline></em></p>

<p align="center">
  <a href="https://www.npmjs.com/package/<pkg>"><img src="https://img.shields.io/npm/v/<pkg>.svg" alt="npm"/></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT"/></a>
</p>

<p align="center">
  <a href="./README.md">简体中文</a> | <a href="./README.en.md">English</a>
</p>

## 截图 / Screenshots

<p align="center">
  <img src="https://raw.githubusercontent.com/<owner>/<repo>/main/assets/screen/demo.gif" width="640" alt="demo"/>
</p>

## 安装 / Install

```bash
<install command>
```

## 功能 / Features

| | |
| --- | --- |
| Feature 1 | short |
| Feature 2 | short |

## 更新日志 / Changelog

See [CHANGELOG.md](./CHANGELOG.md).

## License

MIT.
```

Knobs: Showcase images use raw.githubusercontent.com URLs (render everywhere, stay out of npm tarball). GIF under ~10 MB (compress with ffmpeg, see REFERENCE.md section D). Version number in badge + package.json + CHANGELOG must match.

## F. PUBLISH.md (git-installed DSH plugins)

When: shipping a DSH plugin that users install via dsh plugin --profile web add github:<owner>/<repo>. Document the three config knobs.

```markdown
# Installing from git

If dsh plugin --profile web add github:<owner>/<repo> fails to start, your profile needs three knobs in ~/.dsh/profiles/<profile>/pnpm-workspace.yaml:

```yaml
allowBuilds:
  'git+https://github.com/<owner>/<repo>.git': true

minimumReleaseAgeExclude:
  - '<pkg>@<current-version>'
```

Then refresh:

```bash
dsh plugin --profile web update
```

Restart the host app for the new bundle to take effect.

Note: <pkg> ships a prebuilt lib/client.js; no prepare script required.
```

## G. GitHub Actions release workflow

When: automating tag + GitHub Release + npm publish from main on version-bump commits.

```yaml
# .github/workflows/release.yml
name: release
on:
  push:
    branches: [main]
    paths:
      - 'package.json'

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          registry-url: https://registry.npmjs.org/
      - run: npm ci
      - run: npm run build
      - run: npm test
      - run: npm version patch --no-git-tag-version
      - run: npm publish --access public --provenance
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
      - run: |
          git config user.name 'github-actions'
          git config user.email 'github-actions@github.com'
          VERSION=$(node -p "require('./package.json').version")
          git tag v$VERSION
          git push origin v$VERSION
      - uses: softprops/action-gh-release@v2
        with:
          generate_release_notes: true
```

Knobs: Replace patch with minor/major for change type. npm version rewrites package.json and stages the change. Store NPM_TOKEN as repo secret with publish scope.

## H. Cargo.toml (crates.io)

When: a Rust crate that you want to ship to crates.io.

```toml
[package]
name = "<crate>"
version = "0.1.0"
edition = "2021"
description = "<one-line purpose>"
license = "MIT"
repository = "https://github.com/<owner>/<repo>"
readme = "README.md"
keywords = ["<kw1>", "<kw2>"]
categories = ["<category-slug>"]
include = ["src/**/*.rs", "Cargo.toml", "README.md", "LICENSE"]
exclude = ["target", "tests/fixtures/**"]

[dependencies]
```

Knobs: categories slugs from crates.io/category_slugs. cargo publish --dry-run first; crates are immutable once uploaded. cargo login <token> from crates.io/settings/tokens.

## I. pyproject.toml (PyPI)

When: a Python package that you want to ship to PyPI.

```toml
[build-system]
requires = ["setuptools>=68", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "<pkg>"
version = "0.1.0"
description = "<one-line purpose>"
readme = "README.md"
license = { text = "MIT" }
authors = [{ name = "<user>" }]
requires-python = ">=3.9"
dependencies = []
classifiers = [
  "Programming Language :: Python :: 3",
  "License :: OSI Approved :: MIT License",
  "Operating System :: OS Independent",
]

[tool.setuptools]
packages = ["<pkg>"]
```

Knobs: python -m build produces dist/*.whl + dist/*.tar.gz; twine upload dist/* uploads both. PyPI token from pypi.org/manage/account/token/ with project scope. Versions are immutable on PyPI too.

## J. PyInstaller build script

When: turning a Python app into a standalone .exe for distribution without Python on the target machine.

```bat
@echo off
setlocal

taskkill /f /im findany.exe 2>nul

if exist build rmdir /s /q build
if exist dist rmdir /s /q dist
if exist findany.spec del findany.spec

python -c "import PyInstaller" 2>nul || pip install pyinstaller

python -m PyInstaller --onefile --name findany --clean app.py

echo.
echo Built: dist\findany.exe
endlocal
```

Knobs: Anchor user-visible output on os.path.dirname(sys.executable) not __file__ (PyInstaller __file__ points at temp _MEIPASS and gets cleaned up). Smoke-test by launching exe; absence of crash.log is pass signal. .gitignore should exclude build/, dist/, *.spec, *.log.

