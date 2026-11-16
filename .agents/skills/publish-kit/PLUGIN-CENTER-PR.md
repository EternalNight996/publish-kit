# DSH 插件中心收录 + 宣传 PR 打法（从 memory-eternal 蒸馏）

来源：memory-eternal 的 `PUBLISH.md`、`docs/growth/STAR-PLAYBOOK.md`、`docs/MCP_DISTRIBUTION.md`、`scripts/check-market-shots.mjs`、`release-notes-0.*.md`。

一句话判据：**插件中心的「上架」不是交表，是让三条自动扫描链同时命中（npm keywords / GitHub topic / 仓库根 screenshots.json）；「宣传」不是刷帖，是把首屏改成能在 30 秒内被看懂并被 star 的样子。**

---

## 1. 收录链路（7 环，每环都有判定信号）

```text
① package.json keywords 含 dsh-plugin
      ↓ npm publish
② npm registry: <pkg>@x.y.z            ← 市场优先用 npm tarball 安装（快）
③ GitHub 仓库 topic: dsh-plugin        ← 提供 README/截图/star/评分素材
      ↓ ②③ 任一命中即被 registry 收录
④ 仓库根 screenshots.json（作者自声明，不需要 PR）
      ↓ awesome-dsh-plugin nightly 把相对路径 probe 成 raw.githubusercontent.com 绝对 URL
⑤ plugins.json.screenshots
      ↓ 客户端「更新插件市场」
⑥ 卡片缩略图（前 3 张）+ 详情页轮播（≤6 张）
      ↓ 装完按 dsh.marketplace.requiresRestart 重启宿主
⑦ 卡片/详情生效
```

| 环 | 判定信号 | 延时 |
|---|---|---|
| ① keywords | `keywords` 里有 `dsh-plugin`（另加 `deepseek-harness`/`dsh`/领域词） | 发布即生效 |
| ② npm | `npm view <pkg> dist-tags` 的 `latest` 指向新版；`https://registry.npmjs.org/<pkg>/<v>` 返回 **200**（端点会缓存假报，200 是唯一判据） | 分钟级，边缘缓存可达数分钟 |
| ③ topic | Settings → Topics 手工加 `dsh-plugin` | 立即 |
| ④ screenshots.json | 仓库根文件；**只认裸数组或 `{"screenshots":[...]}`** 两种形态（写 map 形态本地校验直接抛错）；每项为相对路径（不以 `/` 开头、不含 `..`）或 GitHub https 绝对 URL；总 1-8 张；**SVG 与第三方图床被拒** | 提交即存在 |
| ⑤ nightly probe | registry 条目 `screenshots` 的 **basename 与顺序**与本地完全一致 | **只在 UTC 02:23（北京 10:23）的 nightly 才 probe**；push 触发的构建不 probe → 推完当天通常看不到，最多等一整夜 |
| ⑥ plugins.json | 按 `name`+`owner` 命中，读 `version`/`updated`/`screenshots` | 客户端 24h 刷新 |
| ⑦ 客户端 | 未声明截图 = 只能在详情弹窗从 README 抽图；声明后策展图零额外请求 | 点「更新插件市场」后立刻 |

**一键验收**（这张图的闭环工具）：

```bash
node scripts/check-market-shots.mjs          # 0=已拾取 1=未拾取/数量或顺序不符 2=网络或解析失败
node scripts/check-market-shots.mjs --json   # 机器可读
node scripts/check-market-shots.mjs --wait   # 每 10 分钟重试，等 nightly
```

三态文案与对策：`not-listed` → 先确认 topic 与 npm 版本；`not-picked` → 等 nightly，别反复推；`mismatch` → 改 `screenshots.json` 的顺序/数量，等下一次 nightly 覆盖。

---

## 2. 主动提 PR / Issue 的对象清单

### 2.1 DSH 生态

| 对象 | 提什么 | 必填 | 退回原因 |
|---|---|---|---|
| `2BingLing/dsh-market` | 收录入口（PR/Issue，形态以仓库当时为准） | 仓库 URL、npm 包名、已打 `dsh-plugin` topic、`screenshots.json` 已声明 | 表单字段快照未留存 `[待核实]` |
| `AwesomeHou/dsh-plugin-marketplace` | 同上 | 同上 | `[待核实]` |
| `awesome-dsh-plugin`（registry 本体） | **不提 PR**：禁止往它的 `data/screenshots.json` 加键——那是旧条目回退，仓库一旦自己声明就会被清理 | — | 往 data 加键 = 白做且会被清 |
| `hashgraph-online/awesome-ai-plugins` | PR 到 DeepSeek Harness Plugins 小节 | 仓库扫描 **≥80 分且无 critical/high** | 无自有 scanner CI → Registry 信任分扣 10%；合法进程启动/网络调用易被误报 high，可把 gate 降到只拦 critical |

### 2.2 MCP / 第三方目录

| 对象 | 形式 | 产物/必填 | 状态 |
|---|---|---|---|
| `punkpeye/awesome-mcp-servers` | PR（示例 #18822） | 条目 + 服务器所有权（`glama.json` maintainers） | open |
| `cline/mcp-marketplace` | Issue（#3603） | 名称/仓库/安装命令/类型/描述 | open |
| `docker/mcp-registry` | PR（#6738） | `Dockerfile` + **镜像 tag 必须指向已发布版本**（钉未发布版本会让 Glama 构建失败） | open |
| 官方 MCP Registry | `mcp-publisher publish`（`make publisher` + `login github`） | `server.json`：`name=io.github.<OWNER>/<PKG>`、`repository`、`version`、`packages[0].registryType=npm`、`identifier=<pkg>`、`transport.type=stdio`、`packageArguments` 含 `positional: mcp` | 需手动登录；命名空间由 GitHub 身份校验，**不需要 DNS** |
| Smithery | `npx -y @smithery/cli login` → `publish <OWNER>/<REPO>` | `smithery.yaml`：`startCommand.type=stdio` + `configSchema` + 启动串含 `npx`/包名/CLI 子命令；格式过旧时 `commandFunction` → `command` | 待发布 |
| Glama | glama.ai GitHub 登录认领 | `glama.json` maintainers + Dockerfile + MCP introspection | 2026-11-09 起暂停 |
| mcp.so / PulseMCP | 网页表单，粘 6 行（名称/仓库/安装/类型/无需 Key/描述） | 描述卖点：审核后才可召回、FTS5/BM25 零模型调用、p50 2.3ms、不可变审计、多宿主共用 | 待手动 |
| `hesreallyhim/awesome-claude-code` | Issue（示例 #3524） | `[待核实]` | open |
| `rohitg00/awesome-claude-code-toolkit` | PR（#919） | `[待核实]` | open |
| Claude 官方插件目录 | **仅网页表单** `https://clau.de/plugin-directory-submission` | `[待核实]` | 人工 |
| `ccplugins/awesome-claude-code-plugins` | 不可提 | 仓库 `has_pull_requests=false` | 通道关闭 |

### 2.3 已被踩过的退回原因（直接抄成 checklist）

1. **三份宿主清单非法 JSON → 第三方市场安装直接失败**：`.claude-plugin`/`.codex-plugin`/`.cursor-plugin` 的 `plugin.json` 曾长期「描述串缺收尾引号 + 双重编码乱码」，DSH 自己不走这三份文件所以一直没暴露。守卫应钉：合法 JSON、`name`/`version` 与 `package.json` 一致、`description.length ≥ 10`、且在 `files` 白名单里。
2. **`server.json` 版本落后 = 用户装到跑不起来的服务**：`version` 与 `packages[0].version` 两处都要跟 `package.json`。
3. **文档里写「带引号的 token 字面量」会被安全扫描判 HARDCODED_SECRET（high）**，连文档示例也扫。示例一律不写引号、不写真实值。

---

## 3. 宣传素材规格（位置 + 硬指标）

| 素材 | 规格 | 落地位置 |
|---|---|---|
| 卡片缩略图（前 3 张） | GitHub 托管位图 png/jpg/jpeg/webp；不以 `/` 开头、不含 `..`；SVG 与第三方图床被拒；**数组顺序 = 展示顺序** | `screenshots.json` 第 1-3 项（放最能打的） |
| 详情页截图 | 总声明 1-8 张，客户端最多展示 6 张 | `screenshots.json` 全部项 |
| 业务页实拍 | Chrome headless + CDP，**1600×1000 @1x**，`captureBeyondViewport:false`，PNG；强制固定皮肤 + 跳过引导，保证截图可复现 | `node scripts/shots.mjs` → `assets/screen/` |
| 品牌 hero | **1600×900 @1x** PNG（≤ ~800 KB） | `assets/screen/hero.png`，README 首屏 |
| OG / Social preview | **1280×640 @1x** PNG | `assets/social-preview.png` + GitHub Settings → Social preview |
| 应用图标 | 400×400（分发材料硬要求） | `assets/icon-400.png`（README 显示 92×92）、`assets/icon.png`（`package.json.icon`） |
| GIF 演示 | **红线 10 MB**（GitHub 不渲染），压到 3-8 MB | README 头部（当前样本改用静态 hero，GIF 为历史方案） |
| 一句话定位（中） | 主标题「让 AI 记住你们一起做过的决定。」；差异句「不是又一个向量库，是你能打开、能审、能回滚的记忆。」 | README 首屏 / landing / Release 首行 |
| 一句话定位（英） | 「Your AI forgets. Give it a second brain you can audit.」；one-liner「Markdown, not embeddings. Review, not autopilot.」 | `README.en.md` 首屏、`site/en.html` |
| 卖点三条 | ① 真实工作流（沉淀/审核/回收/备份/图谱，不是 demo 壳子）② 跨 Agent（一个本地 vault 服务多个宿主）③ 可审计（Markdown + SQLite + 先审后入，对比向量黑盒） | landing 首屏三卡、HN/Reddit 正文 |
| CTA 命令 | 宿主插件：`dsh plugin --profile desktop add <PKG>`；npm 路径：`npx @deepseek-ai/dsh plugin --profile web add <PKG>`；MCP：`npx -y -p <PKG> <CLI> mcp` | README「快速开始」、`llms-install.md` |

---

## 4. 发布公告模板

### 4.1 结构骨架（顺序固定）

```markdown
## <emoji> v<X.Y.Z> — <一句话结论：解决了什么，不是列功能>
> （可选）哪些中间版本未发布、内容并入本版

### 这一版解决什么
<2-4 句讲痛点现场，不写 changelog 体>

### 一、<emoji> <能力名>
| 怎么做 | 判定信号 |
```bash
<完整可粘贴命令>
```

### 二、…
### 五、修的问题        ← 每条写「原行为 → 现行为」
### 六、验证            ← 表格：套件 | 结果（测试数 / 全绿）
### 升级
```bash
npm i -g <PKG>@<X.Y.Z>
cd ~/.dsh/profiles/desktop && pnpm update <PKG>
cd ~/.dsh/profiles/web && pnpm add <PKG>@<X.Y.Z>
```
```

营销型 Release 用更短的四段：① 一句话 ② 用户可感知 ③ 升级注意 ④ 回滚方式。结尾可选 CTA：「如果这个版本帮你少解释了一遍上下文，Star 是最好的支持。」

### 4.2 标题句式库（真实句式）

| # | 模板 | 样例 |
|---|---|---|
| 1 | `<emoji> vX — <能力>：<A> · <B> · <C>` | `🛰 v0.49.11 — MCP 三向打通：云端 HTTP 端点 · 令牌透传 · 三家宿主自动挂载` |
| 2 | `<emoji> vX — <场景名>：<动作1> + <动作2>` | `🔗 v0.49.0 — 多实例协作：MEM Pair 配对 + Agent MCP 挂载标准` |
| 3 | `<emoji> vX — <主定位>：<三个用户收益短语>` | `☁️ v0.47.0 — 云端记忆成为主打：换库不重启、上传可续传、连不上自动回本地` |
| 4 | `<emoji> vX — <用户原话感的症状>` | `🐛 v0.48.3 — 切了云端，自动沉淀不再往本地库写` |
| 5 | `<emoji> vX — <症状>（<为什么现在才发现>）` | `🐛 v0.48.5 — 付费套餐的额度终于真的生效了（云端实测挖出来的）` |
| 6 | `<emoji> vX — <UI 改动>（<原来的错误观感>）` | `🎨 v0.48.2 — 知识卡片 hover 不再变红（看着像"这张卡出错了"）` |
| 7 | `<emoji> vX — <改动>：<A>、<B>、<C>` | `🎛 v0.49.1 — 两张卡重做：挂载改列表点击、配对卡重排` |
| 8 | `<emoji> vX — <功能> + <功能> + <体验修复>` | `🧪 v0.45.0 — 实验性功能分级 + 云端连接 + 备份/检索体验修复` |

emoji 语义分工：`🧪` 实验性 / `☁️` 云端主线 / `🎨` 视觉 / `🐛` 修 bug / `🎛` 交互重做 / `🔗` 多实例 / `🛰` 协议与分发。
**Release 标题自动生成规则**：`--title` = `<tag> — <notes 首个 '## ' 行的正文>` → H2 标题就是公告标题，先说清它给谁用。

---

## 5. 五维评分杠杆

评分口径原文：**用途一句话 + 真实截图 + 安装命令 + 目录结构 + 待办**。权重未公开 `[待核实]`。

| 维度 | 喂给评分的段落 | 拿分写法 |
|---|---|---|
| 用途 | H1 + 首个 `##` 首句 | H1 用「对象 + 收益」；首段 3 句内说完是什么/给谁/不做什么；差异句同屏 |
| 截图 | 头部 icon + hero，正文双列实拍 | 首屏第一张必须是当前版本真实界面并标注「界面预览 + 在线 Demo」；引用图必须真实存在（守卫会红） |
| 安装 | `## ⚡ 快速开始` | 命令必须是当前版本可跑的，别留旧 pin；每条后写「你会看到什么」；桌面版与 web 版分别给 profile 名 |
| 目录结构 | **常见缺口**：README 里常只有架构图没有目录树 | 补一节「仓库结构」：每个目录一行用途（host 半边 / 面板 / CLI / hooks / skills / 各宿主清单 / docs）。架构图不能替代 |
| 待办 | **常见缺口**：重构 README 时 Roadmap 易被删掉 | 补 `## 🗺 Roadmap`：已实现 / 进行中 / **不做（含理由）**；「不做」栏最有说服力 |
| 附加 | 头部 4 枚徽章（stars / npm v / release / license） | release 徽章版本号手写，发版必须同步 |

---

## 6. 渠道清单

| 渠道 | 提交物 | 判定成功 | 复查 |
|---|---|---|---|
| npm | keywords 含 `dsh-plugin`、files 白名单、tag 触发 OIDC 发布 | `latest` = 新版；版本端点 200；tarball 无私有文件 | `npm view <PKG> dist-tags` |
| GitHub | 仓库 + topic `dsh-plugin` + Release + Pages + social preview | Release 存在；tag peeled 指向 HEAD；Pages 无 404 | `gh release view v<X>`；`git ls-remote origin refs/tags/v<X>*` |
| Gitee | tag + Release（`tag_name/name/body/target_commitish=main`） | Release 列表出现该 tag | `node scripts/release.mjs --only-gitee` |
| DSH 插件中心 | npm + topic + `screenshots.json` + `dsh.marketplace` 声明 | registry 条目存在且 screenshots 顺序一致 | `node scripts/check-market-shots.mjs` → 0 |
| awesome-dsh-plugin | 只靠仓库自声明，禁 PR data 文件 | nightly 后 plugins.json 抓到绝对 URL | `--wait` |
| MCP 官方 Registry | `server.json` + `mcp-publisher publish` | 按 `io.github.<OWNER>/<PKG>` 查到 | 登录发布 |
| Smithery | `smithery.yaml` | publish 成功且 npx 启动串可跑 | `npx -y @smithery/cli publish <OWNER>/<REPO>` |
| Glama | `glama.json` + Dockerfile（钉已发布 tag） | 认领成功 + 徽章回填 | 暂停中 |
| 安全扫描 registry | 自有 scanner CI（min_score 80 / fail critical） | ≥80 且无 critical/high | CI 日志 |
| 中文社区首发 | 标题库 + 在线 Demo + GitHub；**首发只发一次，48h 后再下一个渠道** | referrers 前 3 渠道 + clones 上升 | Insights → Traffic |
| 英文社区 | 第 2 周；HN 不写营销词，正文给「为什么做 / 怎么做 / 限制」 | 同上 | 同上 |
| 安装后转化 | ① 反馈弹窗底部「去 GitHub 点 Star →」② 设置页底部链接（与版本号同行）③ Release 结尾 CTA | star/view 转化率回升；**不得「Star 解锁功能」** | 自建埋点 |
| Star 提示硬约束 | 召回 ≥8 或卡 ≥15 才问；7 天冷却；最多 3 次；「不再提示」永久 | 没用起来不许问（写成守卫测试） | `tests/star-prompt.test.mjs` 范式 |

---

## 7. 红线

- 不买 star、不互 star 群——短期数字，长期毁推荐权重。
- 不在多个社区同一天发同一段文案——按 spam 处理。
- 不承诺「永久记忆 / 100% 准确」——审核与召回都有边界，诚实更容易被推荐。
- 不用旧截图配新文案——「界面预览」与「当前安装版」必须分别标注。
- Demo 不接真实数据——示例数据独立文件夹，绝不把真实 vault 提交到公开仓库。
- 不用「最强 / 颠覆 / 替代所有」这类词（HN 尤其）。

---

## 8. 提 PR 前 checklist

- [ ] npm 版本端点 200，`dist-tags.latest` 正确
- [ ] GitHub topic `dsh-plugin` 已加，仓库 public
- [ ] `screenshots.json`：1-8 张、纯位图、相对路径、前 3 张是最强截图
- [ ] `package.json#dsh.marketplace` 声明 `profiles` / `requiresRestart` / `manualSteps`
- [ ] 三份宿主 `plugin.json` JSON 合法且版本同步；`server.json` 两处版本同步
- [ ] 自有 scanner 扫描 ≥80 且无 critical/high
- [ ] README 五维齐备（用途/截图/安装/目录结构/待办）
- [ ] 一次只推进一个渠道，48 小时看数据再决定下一个
