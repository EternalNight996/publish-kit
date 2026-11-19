# 发布分级与审批闸门（Release grades & approval gate）

业主规则（硬约束）：**正式版必须由业主明文批准后才能发。** 任何未经批准的改动，最高只能以**测试版**（alpha / beta / rc）发布。没有例外，没有「这次很小」。

一句话判据：**先问级别，再问命令。级别没定，不许碰 `npm publish`。**

---

## 1. 五级定义与映射

| 级别 | 定义 | 版本号 | npm dist-tag | GitHub Release | git tag | 谁能发 | 安装命令 |
|---|---|---|---|---|---|---|---|
| **Alpha (α)** | 内部测试版，最早预览；功能可能不完整、稳定性差，只给开发团队内部试 | `X.Y.Z-alpha.N` | `alpha` | Pre-release（标注 alpha） | `vX.Y.Z-alpha.N` | 开发者本人 | `<pkg>@alpha` |
| **Beta (β)** | 公开测试版；功能基本完成，仍可能有缺陷，面向更广用户收集反馈 | `X.Y.Z-beta.N` | `beta` | Pre-release | `vX.Y.Z-beta.N` | 开发者本人（**默认级别**） | `<pkg>@beta` |
| **RC** | 候选发布版；逼近正式版，只修 bug 与稳定性；无重大问题即可转正 | `X.Y.Z-rc.N` | `rc` | Pre-release | `vX.Y.Z-rc.N` | 开发者本人 | `<pkg>@rc` |
| **Release** | 正式版；稳定、可用于生产，功能完整、已知 bug 已修 | `X.Y.Z` | `latest` | Production（非预发布） | `vX.Y.Z` | **业主批准后** | `<pkg>` 或 `<pkg>@latest` |
| **Patch** | 补丁版；只含 bug 修复与微小改进，**不引入新功能** | `X.Y.Z+1` | `latest` | Production | `vX.Y.Z+1` | **业主批准后** | `<pkg>@X.Y.Z+1` |

硬规则：
- **`latest` 只承载 Release / Patch。** alpha / beta / rc 永远不能落到 `latest`。
- **预发布不能自称正式版**：Release notes、README、公告里不许把 beta 写成「最新稳定版」。
- **版本号一旦发出去就不可回收**：npm 同版本不能重发，只能提新号；tag 也不要删（删了会让别人引用的 URL 变空）。

---

## 2. 审批闸门（唯一允许的四种放行方式）

`Release` / `Patch` 必须在**同一轮对话或同一张工单**里拿到业主的明文许可，然后任选其一放行：

| 放行方式 | 用法 | 适用 |
|---|---|---|
| A. 对话内授权 | 业主本轮原话含「批准 / 同意 / 发正式版 / 转正 / 发 patch」等明确词 | 日常 |
| B. 环境变量 | `PUBLISH_KIT_APPROVED=1`（值必须为 `1`） | 脚本 / CI 手工触发 |
| C. 显式署名 | `--approved-by=<业主标识>` 或 `-ApprovedBy <业主标识>` | 需要留痕 |
| D. 预发布转正 | `--promote-from-beta --approved-by=<业主标识>` | 把已验证的 rc/beta 升为正式版 |

未通过闸门时脚本的**正确行为**：打印拒绝原因 + 打印「已按 beta 发布的等价命令」，`exit 2`。不带 `--grade` 又要求正式版时，一律降级为 beta 并明确告知——**降级不是授权**。

反模式（每条都等于违规）：
- 因为「改动很小 / 只是文档 / 老板应该不会反对」直接发 `latest`。
- 先用 `--pre-release ""` 或空 grade 绕过闸门。
- 先发 `latest` 再补一句「有问题我再修」。
- 把 beta 的 tag 改名成正式 tag。
- 在 CI 里把 `PUBLISH_KIT_APPROVED=1` 写死（等于永久放行）。

---

## 3. 命令矩阵

```bash
# ── Alpha：内部预览 ────────────────────────────────
./scripts/bootstrap-release.sh minor --grade alpha        # vX.Y.Z-alpha.1 → dist-tag alpha + Pre-release
./scripts/bootstrap-release.sh --grade alpha --grade-bump 2   # vX.Y.Z-alpha.2

# ── Beta：默认级别，公开测试 ──────────────────────
./scripts/bootstrap-release.sh minor --grade beta         # vX.Y.Z-beta.1 → dist-tag beta + Pre-release
./scripts/bootstrap-release.sh --grade beta --grade-bump 2    # vX.Y.Z-beta.2

# ── RC：候选版，冻结功能 ──────────────────────────
./scripts/bootstrap-release.sh minor --grade rc           # vX.Y.Z-rc.1 → dist-tag rc + Pre-release

# ── Release：正式版（需批准）──────────────────────
PUBLISH_KIT_APPROVED=1 ./scripts/bootstrap-release.sh minor --grade release
./scripts/bootstrap-release.sh minor --grade release --approved-by=<业主标识>

# ── Patch：补丁正式版（需批准，禁止新功能）────────
PUBLISH_KIT_APPROVED=1 ./scripts/bootstrap-release.sh patch --grade patch

# ── 转正：把已验证的预发布升为 latest（需批准）───
./scripts/bootstrap-release.sh --grade release --promote-from-beta \
    --promote-version=vX.Y.Z-rc.1 --approved-by=<业主标识>
```

Windows（PowerShell）把 `./scripts/bootstrap-release.sh` 换成 `.\scripts\bootstrap-release.ps1`，参数写成 `-Grade beta`、`-GradeBump 2`、`-ApprovedBy <业主>`、`-PromoteFromBeta`；`-BumpType` 可省略（默认 `patch`）。若本机执行策略拦未签名脚本，用 `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\bootstrap-release.ps1 -Grade beta -DryRun` 调。**

调之前先 `--dry-run` / `-DryRun`：它只打印级别、目标版本、dist-tag、tag 名、Release 类型与「是否已获批准」，并**回滚 `package.json`**（试跑不留痕）。

手动发布（不用脚本）时的等价闸门：

```bash
# beta
npm publish --registry=https://registry.npmjs.org/ --access public --tag beta
gh release create vX.Y.Z-beta.1 --prerelease --title "vX.Y.Z-beta.1" --notes-file notes.md

# release（先拿到批准）
npm publish --registry=https://registry.npmjs.org/ --access public --tag latest
gh release create vX.Y.Z --prerelease=false --title "vX.Y.Z" --notes-file notes.md
```

---

## 4. 提级路径（正常升级顺序）

```text
改动完成 → alpha（内部自测）→ beta（公开测试，收反馈）→ rc（冻结功能，只修 bug）→ 业主批准 → release
                                                                        └→ 已有正式版时的小修 → 批准 → patch
```

允许跳级：`alpha → beta`、`beta → release`（业主批准）。**禁止降级复用**：正式版出问题不能把 `latest` 指回旧 beta，只能发 `patch`（或 `release`）修复，或用 `npm deprecate` 标注坏版本。

每次提级都要更新的东西：`package.json#version`、CHANGELOG 对应条目、README 的 Release log、本次 tag、Release notes 级别标注、dist-tag。

---

## 5. 各级别必须齐备的渠道

| 级别 | npm | git tag（双远端） | GitHub Release | Gitee Release | 市场收录 | README/CHANGELOG |
|---|---|---|---|---|---|---|
| Alpha | `alpha` tag | 推 | Pre-release | 可选 | 不刷新 | CHANGELOG 必写 |
| Beta | `beta` tag | 推 | Pre-release | 可选 | 不刷新 | CHANGELOG + README release log |
| RC | `rc` tag | 推 | Pre-release | 可选 | 不刷新 | CHANGELOG + README release log |
| Release | `latest` | 推 | Production | 必需 | 刷新 | 三处同步 |
| Patch | `latest` | 推 | Production | 必需 | 刷新 | 三处同步 |

判定成功（缺一不可）：`curl -s -o /dev/null -w "%{http_code}" https://registry.npmjs.org/<pkg>/<version>` → `200`；`git ls-remote --tags <remote> 'v<version>*'` 的 `^{}` 行等于本次 commit；`gh release view v<version>` 退出码 0；正式版还要 `npm view <pkg> dist-tags` 的 `latest` 指到本版。

---

## 6. 错误表

| 现象 | 根因 | 修法 |
|---|---|---|
| `npm install <pkg>` 装到测试版 | 预发布用了 `--tag latest`，或 `npm publish` 时忘了 `--tag` | 发预发布必须要 `--tag beta/rc/alpha`；已污染则发正式版覆盖 `latest` |
| 脚本 `exit 2` 并打印「需要业主批准」 | 走了 release/patch 但没闸门 | 拿到批准后加 `PUBLISH_KIT_APPROVED=1` 或 `--approved-by=` |
| 想撤回一个 beta | 不想让别人装到 | 不要删版本；发 `npm deprecate <pkg>@<bad> "superseded by <good>"` |
| RC 之后又加功能 | 破坏 RC 语义 | 加功能就退回 beta；RC 只允许修复 |
| Patch 里混进新功能 | 违反补丁语义 | 拆成 minor Release；补丁只放修复 |
| 正式版发出去 `latest` 没动 | 未显式 `--tag latest` 或 dist-tag 被旧版占用 | `npm dist-tag add <pkg>@<ver> latest` 并复核 |

---

## 7. 发布前自检（按级别取用）

- [ ] 级别已定：alpha / beta / rc / release / patch，且写进 CHANGELOG 标题
- [ ] 正式版：批准来源已记录（对话原话 / `--approved-by` / 工单号）
- [ ] 版本号符合级别（预发布必须是 `X.Y.Z-<tag>.N`）
- [ ] `npm pack --dry-run` 清单与体积已看过
- [ ] CHANGELOG、README release log、本次 tag 三处版本一致
- [ ] 预发布：npm 用非 `latest` dist-tag，GitHub Release 勾 Pre-release
- [ ] 正式版：四渠道齐（npm / 双远端 tag / GitHub Release / Gitee Release）+ `latest` 复核
- [ ] 发布后跑一次安装冒烟：`npm pack <pkg>@<version>` 解包看内容
