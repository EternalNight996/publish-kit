# README 设计规范（从 memory-eternal 现行 README 蒸馏）

来源样本：`F:\MyApp\eternal\memory-eternal\README.md`（481 行正文 / 28,862 B，19 个 `##` / 0 个 `###` / 10 对围栏）+ `README.en.md`（490 行正文 / 29,401 B，同样 19 个 `##`）。两份标题层级逐项对齐、围栏数量相等，由测试守卫钉死。

一句话判据：**README 是 30 秒落地页，不是手册。** 手册在 `docs/`，README 只负责「看懂 → 想试 → 装得上 → 敢 star」。

---

## 1. 章节顺序骨架（19 节，固定序）

头部（H1 + icon + hero + 4 badge + 语言行，共 14 行）之后，按此序：

| # | 章节 | 行区间 | 字符数 | 存在理由 |
|---|---|---|---|---|
| 1 | ☁️ 本版主打能力 | 16-49 | 1356 | 本版最强卖点前置：一句断言 + 能力表 + 可粘贴命令 |
| 2 | 📊 与同类实测对比 | 50-91 | 1716 | 用可复核数字换信任，必带口径 blockquote |
| 3 | 🏷 命令名与别名 | 92-110 | 397 | 消除入口困惑（一名一入口） |
| 4 | ⚡ 快速开始 | 111-134 | 569 | **唯一**安装节，通道 ≤4 条，Star CTA 收尾 |
| 5 | 🧾 反向自证（真的省 X 吗？） | 135-156 | 429 | 教用户自己算账，不自夸 |
| 6 | 🛡️ 核心机制（先审核再入库） | 157-169 | 339 | 安全模型就是差异点，纯分点 |
| 7 | ⭐ 核心概念 | 170-181 | 258 | 最短节：一个概念 + 6 条行为约定 |
| 8 | 🧩 宿主/平台支持 | 182-235 | 2651 | 全文最长允许在此：5 列表 + 8-10 条分点 |
| 9 | 🔍 默认形态与升级路径 | 236-248 | 308 | 三档表，回答「要不要额外装东西」 |
| 10 | 🎨 皮肤与界面 | 249-270 | 600 | 1 大图 + 2 并排图 + 主题表 |
| 11 | 🏗 架构 | 271-338 | 1451 | 唯一 mermaid 图 + 不变量表 |
| 12 | 🔗 进阶机制 A | 339-363 | 817 | 阶段表（阶段/怎么做/**判定信号**）+ bash |
| 13 | 🔌 进阶机制 B（集成/MCP） | 364-402 | 1209 | bash + `text` 块画面板线框（比截图省体积） |
| 14 | 🧷 多实例/多环境 | 403-425 | 726 | 三维度表（维度/怎么设/默认） |
| 15 | 📚 文档与链接 | 426-433 | 436 | 出口：深度内容全外包 `docs/` |
| 16 | 💬 社群与赞助 | 434-449 | 874 | 图片撑版面，正文 ≤120 字 + 自愿声明 |
| 17 | 📄 License | 450-453 | 33 | 一行人话结论，禁贴条文 |
| 18 | 🖋 作者语录 | 454-471 | 232 | 人格化收尾，纯引用不解释 |
| 19 | 🌟 贡献者 | 472-481 | 376 | 只列真实合并项 + 一句招募 |

节奏硬指标：
- 字符中位数 ≈ 570；**≤400 字符的「呼吸节」保持 ≥8 个**；**>1400 字符的「重节」≤4 个**。
- 标题格式恒定：**1 个 emoji + 空格 + 名词短语**（H1 与全部 H2 一致）。
- **无 `###` 三级标题、无锚点目录、无 `<details>` 折叠、无 `---` 分隔线**（样本实测：details=0、toc=0、hr=0）。需要收起的宿主列表改写成「默认显示 3 个 + 展开其余 N 个」的产品内交互。

---

## 2. 头部模板（可直接复制）

```markdown
# 🧠 {PKG} —— {给谁}{装什么}，{最大卖点 12-20 字}

<p align="center"><img src="assets/icon-400.png" width="92" height="92" alt="{PKG} icon" /></p>

<p align="center"><img src="assets/screen/hero.png" width="100%" alt="{这张图证明了什么}" /></p>

<p align="center">
  <img src="https://img.shields.io/github/stars/{OWNER}/{REPO}?style=flat" alt="stars" />
  <img src="https://img.shields.io/npm/v/{PKG}" alt="npm" />
  <img src="https://img.shields.io/badge/release-v{X.Y.Z}-{HEX_ACCENT}" alt="release" />
  <img src="https://img.shields.io/badge/license-{MIT}-blue" alt="license" />
</p>

[English](README.en.md) · **简体中文（默认）**
```

规则：
- badge **只 4 个**：社会证明 → 版本 → 版本徽标 → 许可。不加 CI、下载量、平台矩阵。
- 每个 `<img>` 必带 `alt`，alt 写「证明了什么」而不是文件名。
- 素材体积实测上限：icon-400 ≈ 80 KB（显示 92×92）、hero ≈ 790 KB（`width="100%"`）、social-preview ≈ 430 KB（1280×640，只用于 GitHub 仓库 Social preview，不进 README）。
- 需要在 npm/镜像站也渲染的图（群码、收款码）用 **raw.githubusercontent.com 绝对 URL**，并确保已 push 到默认分支。

---

## 3. 双语拆分规则

| 项 | 规定 |
|---|---|
| 文件名 | `README.md`（中文，默认）+ `README.en.md`（英文镜像），**两者都必须进 `package.json.files`**，否则 npm 页缺一份 |
| 切换链接 | 各写各的：中文 `[English](README.en.md) · **简体中文（默认）**`；英文 `**English** · [简体中文（默认）](README.md)`，位置固定在 badge 行之后空一行 |
| 对齐守卫 | 标题层级序列逐项相等 + 代码块数量相等（各为偶数）+ 标题数 ≥8 + `docs/` 四份文件存在 + CHANGELOG 含当前版本行。写成一条测试（`tests/readme-i18n.test.mjs` 范式），否则改一半必然漂移 |
| 允许差异 | 换行宽度（英文 ~100 字符硬换行）、标点（`——`/`—`、`「」`/`"…"`、`→`/`->`）、表格列名、引用句数、标题改写（emoji 与顺序不变） |

---

## 4. 反模式（这份 README 刻意不做的事）

1. **不放 GIF / 视频**。全篇 `.gif|.webm|.mp4` 命中 0 次；改用静态 hero（790 KB）。旧范式（头部 3 MB GIF）已废弃。
2. **不写完整安装矩阵**。安装只在「快速开始」出现，4 条通道封顶（插件市场 / 全局 CLI / npx 零安装 / HTTP 直连）。
3. **截图不超量**。README 内产品截图 4 张；市场卡片走 `screenshots.json`（1-8 张、客户端最多展示 6 张、缩略图取前 3 张 → 前三张放最能打的）。
4. **不堆大参数表**。最宽 8 列，常规 3-5 列 / 3-7 行；参数细节外包 `docs/`。
5. **不内嵌更新日志**。README 只放一行「更新日志」链接；发版正文从 `docs/CHANGELOG.md` 的单行表格抽取 → **单行说明是上限，不是下限**。
6. **不写手册**。深度内容在 `docs/GUIDE*.md`、`docs/CHANGELOG.md`、`docs/ARCHITECTURE.md`。
7. **不用折叠块/目录藏内容**。
8. **不承诺无依据的数字**。示意数字必须紧跟免责（「以上是示意数字，不是 benchmark」「检索分 ≠ QA 分」）。
9. **不搬 License 全文**。一行结论 + 放在倒数第三节。

已知脆弱点（务必在发布清单加一步）：`release` badge 里的版本号是**硬编码**，与 `package.json.version` 无测试同步 → 每次发版手动改，或用 `sed` 一步替换。

---

## 5. 填空式骨架

````markdown
# 🧠 {PKG} —— {给谁}{装什么}，{最大卖点}
<!-- 定位句：「给 X 装一个 Y」或「让 X 不再 Y」；不加副标题、不加宏大叙事 -->

<p align="center"><img src="assets/icon-400.png" width="92" height="92" alt="{PKG} icon" /></p>
<p align="center"><img src="assets/screen/hero.png" width="100%" alt="{证明了什么}" /></p>
<p align="center">
  <img src="https://img.shields.io/github/stars/{OWNER}/{REPO}?style=flat" alt="stars" />
  <img src="https://img.shields.io/npm/v/{PKG}" alt="npm" />
  <img src="https://img.shields.io/badge/release-v{X.Y.Z}-{HEX}" alt="release" />
  <img src="https://img.shields.io/badge/license-{MIT}-blue" alt="license" />
</p>

[English](README.en.md) · **简体中文（默认）**

## ☁️ {本版头号能力}（v{X.Y.Z} 主打）
**{一句反常识断言，加粗}。** {2-3 行说明为什么成立，不铺垫}

| 能力 | 你能得到 |
|---|---|
| **{短名}** | {具体到文件名/端点/参数} |

```bash
# ① ... ② ... ③ ...    # 编号注释三步，每步 ≤2 行
```

> {必须记住的 2 个变量或 1 条边界，≤3 行}

## 📊 与同类产品的实测对比
> 数据日期 **{YYYY-MM-DD}**：{来源}；按各自原文口径转录，不同指标绝不混排。

**表 1 · {维度}**
| 排名 | 项目 | {维度A} | {维度B} | 总分 |

**表 2 · {公开基准与硬指标}**
| 项目 | Stars | 公开成绩（原文口径） | {布尔列} |

## 🏷 命令名与别名
| 命令 | 用在哪 |

## ⚡ 快速开始
```bash
{plugin install 命令}      # 装完看到什么
{npm i -g 命令} && {子命令}
npx -y -p {PKG} {cli} {subcmd}
curl -s {endpoint} -d '{...}'
```
<p align="center"><strong>⭐ {不带愧疚感的 Star 引导}</strong></p>

## 🧾 {真的省 X 吗？}
| 记录项 | 含义 |
```text
{一行公式}
```
> {免责：示意数字；低于 X 就关掉}

## 🛡️ {先 X 再 Y}
- {6 条行为约定，一条一行}

## ⭐ {核心概念}
- {6 条}

## 🧩 宿主支持（一份库，谁都能用）
| 平台 | 接入 | 配哪个文件 | 自动挂载 | 验证 |
- **{宿主}** —— {方式}：`{命令}`；{一句差异}

## 🔍 {默认形态}
| 方式 | 说明 |

## 🎨 {皮肤与界面}
| 主题 | 风格 |
<p align="center">
  <img src="assets/screen/{a}.png" width="49.5%" alt="{A}" />
  <img src="assets/screen/{b}.png" width="49.5%" alt="{B}" />
</p>

## 🏗 架构：{三顿号概括}
```mermaid
flowchart TB
  subgraph {层}["{层名}"]
    {节点}["{文件}<br/>{职责}"]
  end
```
| 不变量 | 由什么保证 |

## 🔗 {进阶机制 A}
| 阶段 | 怎么做 | 判定信号 |
```bash
{cli} {subcmd} {ARGS}
```

## 🔌 {集成标准}
```text
● {2 / 6} 已挂载   [刷新] [自检]
```
- **{交互细节}**；**{平台坑}**；

## 🧷 多实例并行
| 维度 | 怎么设 | 默认 |

## 📚 文档与链接
- [完整手册](docs/GUIDE.zh-CN.md) · [Full manual](docs/GUIDE.md)
- [更新日志](docs/CHANGELOG.md) · [反馈问题]({issues})

## 💬 交流群
| {群 A} | {群 B} |
|:---:|:---:|
| <img src="{raw URL}" width="240" alt="{群 A}二维码" /> | <img src="{raw URL}" width="240" alt="{群 B}二维码" /> |
> 打赏完全自愿，不影响功能；本体开源免费。

## 📄 License
{MIT} —— {一句人话结论}。

## 🖋 {作者语录}
> {2-5 行，末尾 <p align="right"><sub>——{出处}</sub></p>}

## 🌟 贡献者
| 贡献者 | 贡献 |
````

---

## 6. 验收（可判定）

```bash
# 结构对齐：先剥掉围栏内容，再比对 H2 序列（围栏里的 bash 注释也以 # 开头，直接数标题会被骗）
node --input-type=module -e "import fs from 'node:fs';
const seq=f=>fs.readFileSync(f,'utf8').replace(/\r\n/g,'\n').replace(/^\u0060\u0060\u0060[\s\S]*?^\u0060\u0060\u0060/gm,'').split('\n').filter(l=>/^## /.test(l));
const z=seq('README.md'),e=seq('README.en.md');
console.log('zh',z.length,'en',e.length);
const ok=z.length===e.length&&z.length>=8;
process.exit(ok?0:1)"

# 硬编码版本号与 package.json 一致（release badge 无测试守卫）
node --input-type=module -e "import fs from 'node:fs';const p=JSON.parse(fs.readFileSync('package.json','utf8'));
process.exit(fs.readFileSync('README.md','utf8').includes('v'+p.version)?0:1)"

# 素材体积（hero/GIF 超 1.2 MB 即报，GIF 硬红线 10 MB）
node --input-type=module -e "import fs from 'node:fs';for(const f of fs.readdirSync('assets/screen')){
const s=fs.statSync('assets/screen/'+f).size;if(s>1200*1024)console.log('TOO BIG',f,s)}"

# 市场截图声明合规（1-8 张、png/jpg/webp、相对路径无前导 / 与 ..）
npm run check:market
```

配套三件套缺一不可：`screenshots.json`、`docs/CHANGELOG.md` 的 `| **vX.Y.Z** | 日期 | 说明 |` 单行、`tests/readme-i18n.test.mjs` 那条对齐守卫。
