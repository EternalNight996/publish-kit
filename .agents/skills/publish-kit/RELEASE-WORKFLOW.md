# 发布工作流 SOP（从 memory-eternal `scripts/release.mjs` + CI 蒸馏）

来源：`F:\MyApp\eternal\memory-eternal`（v0.49.11 时代）。凡与项目 `PUBLISH.md` 说法冲突处，**一律以代码为准**（冲突清单见 §8）。

一句话判据：**一次发布 = 11 个清单同版本 + npm 版本端点返回 200 + 两个 remote 的 peeled tag 都指向本次 commit + GitHub/Gitee 各一条 Release。缺一条即「未发布完成」。**

---

## 1. 阶段序列（按序，命令可照抄）

`ROOT = F:\MyApp\eternal\memory-eternal`

| # | 动作 | 命令 | 被谁强制 |
|---|---|---|---|
| 0 | 预演（不碰远端） | `node scripts/release.mjs --dry-run` | 只打印将执行动作 |
| 1 | 改版本号（§3 全 11 处） | 手工编辑，或 `npm version patch` | tag 必须 == `v${pkg.version}` |
| 2 | 写更新日志行 | `docs/CHANGELOG.md` 追加 `\| **vX.Y.Z** \| 日期 \| 说明 \|`，或备 `--notes-file=` | notes 抽取源 |
| 3 | 构建 | `node build.mjs` | `prepublishOnly` 再跑一次；产物一致性闸门 |
| 4 | 测试 | `npm test` | 红则拒绝发布 |
| 5 | 发 npm | `node scripts/release.mjs` → 内部 `npm publish --access public` | `publishConfig.registry` 固定官方源 |
| 6 | 打 tag | `git tag -a vX.Y.Z -m "<notes 前两行>"` | 已存在则跳过，转 peel 核对 |
| 7 | 推 main + tag（遍历所有 remote） | `git push <remote> main` / `git push <remote> vX.Y.Z` | remotes 由 `git remote` 动态枚举，不写死 |
| 8 | 核对 tag 指向，错了强制修正 | `git ls-remote <remote> refs/tags/vX.Y.Z*` 比对 `git rev-parse HEAD`，不一致 `git push --force <remote> vX.Y.Z` | 脚本内置 |
| 9 | GitHub Release | `gh release view` 命中改 `edit`，否则 `create --notes-file` | 脚本内置 |
| 10 | Gitee Release | `GET /releases?per_page=100` 去重后 `POST /repos/{o}/{r}/releases`（`tag_name/name/body/target_commitish=main/prerelease`） | 缺 token 只告警并计入退出码 |
| 11 | 汇总退出码 | 有问题清单则 `exitCode = 1` | **非 0 就是未完成** |
| 12 | 提醒用户升级 | `cd ~/.dsh/profiles/desktop && pnpm update <pkg>` / `pnpm add <pkg>@X.Y.Z` | 只是打印，无校验 |

变体开关：`--dry-run`、`--skip-npm`、`--skip-tests`、`--only-gitee`、`--notes-file=<path>`、`--title=`、`--tag=`、`--allow-dirty`、`--allow-tag-mismatch`。

**双发布通道冲突**：本地 `npm publish` 之后再推 `v*` tag 会触发 CI 的 OIDC 发布，撞 `EPUBLISHCONFLICT`。二选一：本地发 npm 时 CI 不发，或改走纯 CI 发 npm。

---

## 2. 硬闸门（拒绝条件 + 报错特征）

| 闸门 | 条件 | 报错特征 |
|---|---|---|
| 版本/tag 不一致 | `--tag` 推导 ≠ `v${pkg.version}` 且无 `--allow-tag-mismatch` | `tag(v…) 与 package.json 版本(…) 不一致` |
| 工作区脏 | `git status --porcelain` 非空且无 `--allow-dirty` | `工作区有未提交改动，拒绝发布` |
| 测试红 | `npm test` 非零（`--skip-tests` 可绕） | `npm test 未通过，拒绝发布：` + 尾 3000 字 |
| 产物与提交不一致 | 测试后再取 `git status`；仅当脏项 ⊆ `{构建产物}` 且 diff 命中 `BUILD_AT` 类标记才放行 | `测试/构建后工作区变脏 —— 多半是改了版本号却没先 build` |
| publish 失败 | 返回非零 | `npm publish 失败（2FA / 网络 / 版本冲突？）` |
| npm 未可见 | 版本端点轮询（36×5s=3min）非 200，且探针文本不含 `previously staged/published version|EPUBLISHCONFLICT|409` | `⚠ npm version 端点仍未可见` → `稍后复核（200 才算真的发布成功）` |
| Gitee token 缺失 | `GITEE_TOKEN` 与 `~/.config/<pkg>/gitee-token` 皆空 | `⚠ 未找到 Gitee token → Gitee Release 未同步（不算成功）` |
| 汇总失败 | problems 非空 | `⚠ 有未完成的发布动作（不要当作已发布完成）` + `exit 1` |
| CI：tag/版本不一致 | `GITHUB_REF_NAME#v` ≠ `package.json.version` | `::error::tag (…) 与 package.json 版本 (…) 不一致，拒绝发布` |
| CI：私有文件泄漏 | `npm pack --dry-run` 命中 `private/`、`runs/`、`cloud-*.js`、`docs/CLOUD.md` 等 | `::error::私有文件出现在发布清单里` |
| CI：扫描分 | 安全扫描 `min_score: 80`、`fail_on_severity: critical`（high 不拦） | 第三方 action 自身报错 |

**不是闸门的三件事（必须人工补）**：
1. **tag 已存在** → 不拒绝，跳过创建并进 peel 核对。
2. **dist-tag 不对** → 无任何 dist-tag 校验；`latest` 停在旧版不会被拦。发布后必须手动 `npm view <pkg> dist-tags`。
3. **漏改版本清单** → 无校验。实际已出现漂移（某子插件清单落后 9 个小版本）。

---

## 3. 版本清单同步点（11 处）

| 文件 | 字段 | 校验 |
|---|---|---|
| `package.json` | `version` | **唯一被脚本强制** |
| `package-lock.json` | 根 `version` + `packages[""].version` | 无 |
| `server.json` | `version` + `packages[0].version` | 无 |
| `cursor-extension/package.json` | `version` | 无 |
| `dsh-tui-plugin/package.json` | `version` | 无 |
| `dsh-tui-plugin/dsh-plugin.json` | `version` | 无 |
| `private/<cloud-pkg>/package.json` | `version` | 无 |
| `.claude-plugin/plugin.json` | `version` | 无 |
| `.codex-plugin/plugin.json` | `version` | 无 |
| `.cursor-plugin/plugin.json` | `version` | 无 |
| `orca-plugin/orca-plugin.json` | `version` | 无 |

派生项（**禁止手改**，构建注入）：`lib/client.js` / `web/app.js` 里的 `CLIENT_VERSION`（源自 `package.json.version`）与 `BUILD_AT`。
文档侧同步：`README.md` / `README.en.md` 的 release badge（硬编码，无测试）、`docs/CHANGELOG.md` 的版本行（notes 抽取依赖）。

加一条防漂移命令（放 pre-flight）：

```bash
node -e "const fs=require('fs');const v=require('./package.json').version;const files=['package-lock.json','server.json','cursor-extension/package.json','dsh-tui-plugin/package.json','dsh-tui-plugin/dsh-plugin.json','.claude-plugin/plugin.json','.codex-plugin/plugin.json','.cursor-plugin/plugin.json','orca-plugin/orca-plugin.json'];let bad=[];for(const f of files){if(!fs.existsSync(f))continue;const j=JSON.parse(fs.readFileSync(f,'utf8'));const g=j.version??j.packages?.['']?.version;if(g!==v)bad.push(f+'='+g)}console.log(bad.length?'DRIFT: '+bad.join(', '):'versions OK '+v);process.exit(bad.length?1:0)"
```

---

## 4. 三端同步契约（唯一可验证信号）

| 端 | 判定命令 | 期望 |
|---|---|---|
| npm 版本可见 | `curl -s -o NUL -w "%{http_code}" https://registry.npmjs.org/<pkg>/<X.Y.Z>` | `200`（**唯一判据**，不看 stdout） |
| npm latest | `npm view <pkg> dist-tags` | `latest: <X.Y.Z>` |
| GitHub main | `git ls-remote origin refs/heads/main` | == `git rev-parse HEAD` |
| GitHub tag | `git ls-remote origin refs/tags/v<X.Y.Z>*` 的 `^{}` 行 | == `git rev-parse HEAD` |
| GitHub Release | `gh release view v<X.Y.Z> --repo <OWNER>/<REPO>` | 退出码 0 |
| Gitee tag | `git ls-remote gitee refs/tags/v<X.Y.Z>*` | peeled == `HEAD` |
| Gitee Release | `curl -s "https://gitee.com/api/v5/repos/<OWNER>/<REPO>/releases?per_page=100"` | 存在 `tag_name == v<X.Y.Z>` |
| 桌面版（GitHub main 源） | `cd ~/.dsh/profiles/desktop && pnpm update <pkg>` | 用户侧手动，**无自动校验** |
| web profile（npm 源） | `cd ~/.dsh/profiles/web && pnpm add <pkg>@<X.Y.Z>` | 用户侧手动 |

remote 写法坑：GitHub 走 `ssh://git@ssh.github.com:443/<owner>/<repo>.git`（22 端口被墙时可用），脚本不做 SSH 处理，靠仓库配置固化。

---

## 5. 失败模式表

| 现象 | 根因 | 修法 |
|---|---|---|
| `⚠ 未找到 Gitee token` | 无环境变量、无 token 文件、或令牌缺 `projects` 权限 | 设 `GITEE_TOKEN` 或写一行文件；权限勾 `projects`；重跑 `--only-gitee` |
| `git push origin main` 卡住 | SSH 22 不可达 | remote 改 `ssh.github.com:443` |
| **`latest` 卡旧版** | tag 打了但 npm 未落地（半发布态） | 复核 `registry.npmjs.org/<pkg>/<X.Y.Z>` 是否 200；不 200 即「不算发布成功」，补发并 `npm dist-tag add <pkg>@<X.Y.Z> latest` |
| `403 Forbidden` on publish | 包名被占 / 同版本重发 | 换名或提版本；doc-only 改动不重发 |
| Release 指向旧 commit | main 未推上去时先建了 tag（历史踩过 4 次） | 脚本 peel 核对 + `git push --force <remote> v<X.Y.Z>` |
| 脚本看起来跑完但实际有漏项 | 推送失败被吞 | 看退出码；非 0 即未完成，按打印的重试命令补 |
| npm 端点滞后 | 轮询超时 | 3 分钟内轮询；超时只记问题不中断，人工复核 |
| CI 撞 `EPUBLISHCONFLICT` | 本地已 publish，tag 又触发 OIDC | `--skip-npm` 或纯 CI 发布 |
| 发版被构建时间戳拦死 | `npm test` 内跑 build，`BUILD_AT` 必变 | 只放行两个 bundle 的 BUILD_AT 漂移 |
| 历史：40 版无 tag / 3 个假 tag | 发版不配套打 tag，事后靠 `commit~N` 猜 | tag 在发版当次建；建前核对 commit 含版本声明；推前 `git show <tag> --format=%s --no-patch` |

---

## 6. 发布说明（notes）的生成规则

| 环节 | 规则 |
|---|---|
| 首选 | `--notes-file=<relpath>`，全文照用 |
| 回退 | 依次找 `docs/CHANGELOG.md` → `README.md`，精确匹配 `startsWith('\| **vX.Y.Z**')` 整行 |
| 整形 | 去首尾竖线 → 按 `\|` 切 → 丢版本列 → ` — ` 连接 → `## vX.Y.Z` + npm 版本 URL + 正文 |
| 落盘 | `os.tmpdir()/<pkg>-release-vX.Y.Z.md`（不进仓库） |
| tag 消息 | notes 前 2 个非空行，` / ` 连接 |
| GitHub 标题 | `--title` 或 `<tag> — <notes 首个 ## 去前缀>` |
| Gitee 标题 | `<tag> — <description 前 40 字>` |
| 抽取约束 | 版本行必须以 `\| **` 开头且带 `**`；否则退化为「CHANGELOG 里没有这一版，请用 --notes-file」 |
| 根目录 `release-notes-*.md` | **不被任何脚本自动读取**，只能 `--notes-file=` 显式喂 |

最短模板（35 行）：`## 🎨 vX.Y.Z — 一句话结论` → `### 你看到的` → `### 为什么`（旧代码）→ `### 改成什么`（新代码 + 分条效果）→ `### 验证`（测试文件名 + 例数 + 实测数值 + 截图路径）→ `> 注意：…`。

最长模板（58 行）：`## ☁️ vX.Y.Z — 主题` → `> 版本合并关系` → `### 安装 / 升级`（bash：`npm i -g` + `pnpm update`）→ `> 升级后必须重启` → `### 本次改动`（①–⑧ 编号）→ `### 重点`（5 条加粗结论）。

---

## 7. 发布后收尾（脚本不做的）

1. `npm view <pkg> dist-tags` 确认 `latest` 已指向新版；不对则 `npm dist-tag add <pkg>@<X.Y.Z> latest`。
2. `npm pack --dry-run` 核对 tarball（私有文件、体积、`README.en.md` 在不在）。
3. README release badge 版本号改成本版（无测试守卫）。
4. 仓库 fields：Description + Topics（`dsh-plugin`）——Topics 是独立端点 `PUT /repos/{o}/{r}/topics`，混进 PATCH 会 400。
5. 市场刷新与截图声明校验：`npm run check:market`。
6. 给用户升级指令（桌面版走 GitHub main，web profile 走 npm）。

---

## 8. 代码为准的纠正项（记忆-eternal 实测冲突）

| 旧文档说法 | 代码实际 |
|---|---|
| 「`npm test` 29 个单测」 | `node build.mjs` + 串行 163 个测试文件（磁盘 171 个，8 个未接入） |
| 「`files` 白名单 8 项」 | 37 条 include + 13 条 `!` 排除；`PUBLISH.md` 本身不在 tarball |
| 「手工 `git push origin main` + `git push gitee main`」 | 遍历 `git remote` 全推 + peel 核对 + 必要时 `--force` |
| 「发布后确认 dist-tags」 | 脚本无 dist-tag 校验，必须人工 |
| 「只有本地 `npm publish`」 | 另有 tag 触发的 OIDC 发布通道，二者互斥 |
| 「`dsh.lifecycle.scripts` 含 prepare」 | 声明了 `prepare` 但 `scripts` 段无该条目（悬空声明） |

---

## 9. 一键验收（发布后真跑）

```bash
V=$(node -p "require('./package.json').version")
echo "== npm version endpoint =="; curl -s -o NUL -w "%{http_code}\n" "https://registry.npmjs.org/<pkg>/$V"
echo "== dist-tags =="; npm view <pkg> dist-tags
echo "== tag peeled on both remotes =="; for r in $(git remote); do git ls-remote $r "refs/tags/v$V*"; done
echo "== head =="; git rev-parse HEAD
echo "== gh release =="; gh release view "v$V" --repo <OWNER>/<REPO> --json tagName,isPrerelease -q '.tagName'
```

四项全绿才算发布完成；任何一项失败 → 按 §5 修，不要宣布完成。
