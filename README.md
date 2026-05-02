# cc-memory-arch

Claude Code memory 路由 + curation plugin。
强制走 skill 决策，自动分类到 USER.md / 全局 entry / topics / per-cwd 四层。

## 解决什么问题

cc 原生 auto-memory 把所有"记住 X"都写到 per-cwd 路径，导致：

- 用户级偏好被困在某个 repo（换个 cwd 启动 cc 就读不到）
- 跨项目工作流（agent 调用规范、PR 风格）要重复发现
- CLAUDE.md / MEMORY.md 长期无人 curate，膨胀成杂物间
- agent 看到 cwd 下已有同名 entry 就直接 append，**绕过了归类决策**

## 核心机制

1. **PreToolUse hook 拦截** Write / Edit / MultiEdit 到 memory 路径的调用
2. 检查最近是否激活过 `mem-write` skill；未激活 → exit 2 拒绝 + 把指引回传给模型
3. 模型按指引 invoke `mem-write` skill 进行分类
4. skill 决策树定目标层：
   - **项目级**（含本仓库特有概念，换 cwd 失效）→ `~/.claude/projects/<hash>/memory/`
   - **用户级简短偏好**（一两句）→ `~/.claude/memory/USER.md` 段位由 agent 自判
   - **用户级工作流偏好**（多条规则、需独立 entry）→ `~/.claude/memory/<feedback_*>.md` + 更新 MEMORY.md
   - **跨项目技术栈**（Electron/MCP/CI 等）→ `~/.claude/topics/<topic>.md`
5. 模型按 skill 输出写入；hook 放行
6. PostToolUse hook 做容量审计 + 索引同步检查

强制点：**模型不能绕开 skill 直接写**——hook 在工具调用层拦截，比纯 prompt 引导可靠。

## 目录结构

```
cc-memory-arch/
├── .claude-plugin/plugin.json
├── skills/mem-write/SKILL.md       # 分类决策树（核心）
├── hooks/
│   ├── pre-mem-write.sh            # 强制 skill
│   ├── post-mem-write.sh           # 容量 / 索引审计
│   └── lib.sh
├── templates/claude-md-snippet.md  # @-import 进 ~/.claude/CLAUDE.md
├── install.sh
├── uninstall.sh
└── README.md
```

## 安装

需要 cc ≥ 2.1。

### 推荐：通过 cc 内建 plugin marketplace

在 cc 会话里：

```
/plugin marketplace add cheats1314/cc-memory-arch
/plugin install cc-memory-arch@cc-memory-arch
```

cc 会自动 clone 仓库到本地 plugin 缓存、注册 skill、注册 hooks。**无需手动 ./install.sh，无需改 CLAUDE.md / settings.json**。

升级：

```
/plugin marketplace update cc-memory-arch
```

### 备选：脚本手动安装

需要 `bash` / `jq`。适合不想走 cc plugin 机制的人，或想审一遍脚本动作。

```bash
git clone https://github.com/cheats1314/cc-memory-arch.git
cd cc-memory-arch && ./install.sh
```

完全退出当前 cc 会话（exit / Ctrl+D）后重开，安装即生效。

**clone 目录之后可删**——`install.sh` 是 `cp -r` 真安装，安装产物独立于源目录，不依赖你保留 git clone 位置。

安装会做：
- 复制 plugin → `~/.claude/plugins/cc-memory-arch/`（独立副本）
- 复制 skill → `~/.claude/skills/mem-write/`（cc 默认扫描位置）
- 在 `~/.claude/CLAUDE.md` 末尾追加 `@-import` 指向 plugin snippet
- 在 `~/.claude/settings.local.json` 注册 PreToolUse / PostToolUse hooks（不污染共享的 `settings.json`）
- 初始化 `~/.claude/memory/USER.md` 与 `~/.claude/memory/MEMORY.md`（仅在不存在时）

所有改动**幂等**——重复跑 `install.sh` 不会重复注入或覆盖你已有的 USER.md。

升级：

```bash
cd cc-memory-arch && git pull && ./install.sh
```

`install.sh` 会重新 `cp -r`，更新 plugin/skill 内容；CLAUDE.md / settings.local.json 因幂等不会重复修改。

## 卸载

```bash
~/.claude/plugins/cc-memory-arch/uninstall.sh
```

清除：plugin 副本、skill 副本、CLAUDE.md 中的 `@-import` 行、settings.local.json 中的 cc-memory-arch hooks。
**保留**：`~/.claude/memory/` 与 `~/.claude/topics/` 下所有数据。CLAUDE.md / settings.local.json 都生成 `.bak` 备份。

## 测试

新 cc 会话里：

| 输入 | 期望落点 |
|---|---|
| "记住我喜欢吃辣" | `~/.claude/memory/USER.md` 持久化记忆段 |
| "本项目用 npm 不用 pnpm" | `~/.claude/projects/<hash>/memory/` |
| "Electron native rebuild 命令是 X" | `~/.claude/topics/electron.md` |
| "调用 report agent 时不要覆盖路径" | `~/.claude/memory/feedback_*.md` + 更新 MEMORY.md（多条规则、跨项目通用）|

## 多维度对比评分（16 维 + 加权综合分）

去掉了前一版本中的两个自创维度（"cc plugin 标准化"是 cc 特定术语；"写入路径强制 hook vs prompt"是本项目自定义概念）。
保留 **16 个映射到数据库 / IR / 软件工程领域标准术语** 的维度，加权重得出综合分。

每维度 0–10 分。评分基于各项目公开文档、源码、benchmark；**非 head-to-head 实测**，可能存在偏差，欢迎 issue 修正。
`☁` = 必须云端订阅或 API。

### A. 功能能力（权重 35%）

对应 IR / 数据库术语：data ingestion / retrieval methods / retrieval quality / persistence / data model expressiveness

| # | 维度 | 权重 | claude-mem | MemPalace | memsearch | mem-compiler | supermemory | cc 原生 | **cc-mem-arch** |
|---|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| 1 | 自动数据摄取（ingestion automation） | 7% | **10** | 9 | 9 | 9 | 8 | 7 | 4 |
| 2 | 检索方法（向量 / 全文 / 混合 / RRF） | 10% | 9 | 9 | **10** | 4 | 8 | 1 | 2 |
| 3 | 检索精度（公开 benchmark 数据） | 8% | 5 | **10** | 6 | 0 | 5 | 0 | 0 |
| 4 | 持久性 / 跨会话连续性 | 5% | **10** | **10** | **10** | 9 | 9 | 6 | 8 |
| 5 | 数据模型表达力（实体 / 层级 / 关系） | 5% | 5 | **10** | 6 | 7 | 7 | 3 | 7 |

### B. 部署 / 资源（权重 20%）

对应术语：deployment complexity / resource footprint / data portability / interoperability / installability

| # | 维度 | 权重 | claude-mem | MemPalace | memsearch | mem-compiler | supermemory | cc 原生 | **cc-mem-arch** |
|---|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| 6 | 部署复杂度低（无 daemon / DB 依赖） | 6% | 3 | 4 | 3 | 7 | 8☁ | **10** | **10** |
| 7 | 资源占用低（磁盘 / 内存） | 4% | 4 | 4 | 3 | 7 | **9**☁ | **10** | **10** |
| 8 | 数据可移植性（格式开放 / 可 grep） | 5% | 6 | 7 | 8 | **10** | 3 | **10** | **10** |
| 9 | 互操作性（跨 agent: cc/codex/opencode） | 3% | 6 | 7 | **10** | 4 | 5 | 3 | 3 |
| 10 | 安装易用性（onboarding） | 2% | 5 | 5 | 4 | 6 | 8 | **10** | 8 |

### C. 治理 / 数据质量（权重 20%）

对应术语：data lifecycle (compaction/GC) / deduplication / deletion semantics / observability

| # | 维度 | 权重 | claude-mem | MemPalace | memsearch | mem-compiler | supermemory | cc 原生 | **cc-mem-arch** |
|---|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| 11 | 数据生命周期管理（compaction / GC） | 6% | 4 | 3 | 5 | 6 | 4 | 2 | **9** |
| 12 | 去重 / 冲突解决 | 4% | 4 | 5 | 5 | 6 | 4 | 2 | **9** |
| 13 | 删除语义（hard delete / GDPR-style erasure） | 4% | 4 | 6 | 4 | 4 | 4 | 3 | **9** |
| 14 | 可观测性（日志 / 审计 / 度量） | 6% | **9** | 7 | 6 | 5 | 6 | 4 | 6 |

### D. 隐私 / 成熟度（权重 25%）

对应术语：data privacy & residency / project maturity & community health

| # | 维度 | 权重 | claude-mem | MemPalace | memsearch | mem-compiler | supermemory | cc 原生 | **cc-mem-arch** |
|---|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| 15 | 数据隐私（数据不出本机） | 10% | 9 | **10** | 9 | 9 | 2☁ | **10** | **10** |
| 16 | 项目成熟度（star / 活跃度 / 社区） | 15% | **10** | **10** | 6 | 5 | 6 | **10** | 1 |

---

## 加权综合分（满分 10）

权重设计参考 IR / RAG 系统评估惯例：检索类核心能力（A 区）35% + 部署 20% + 治理 20% + 隐私&成熟 25%。

| 排名 | 项目 | 加权综合分 | 主要优势 | 主要劣势 |
|:-:|---|:-:|---|---|
| 🥇 1 | **MemPalace** | **7.93** | 检索精度 benchmark 第一、数据模型最丰富、隐私本地 | 部署重（300MB 模型）|
| 🥈 2 | **claude-mem** | **7.17** | 自动捕获最强、社区第一、可观测好 | 多组件依赖（Bun+Chroma+uv）|
| 🥉 3 | **memsearch** | **6.81** | 检索方法最完整（BM25+向量+RRF）、跨 agent 唯一满分 | 需要 Milvus，社区中等 |
| 4 | **mem-compiler** | **5.98** | 数据可移植性满分、纯 markdown | 无检索精度数据 |
| 5 | **cc 原生 auto-memory** | **5.89** | 部署/资源/隐私/成熟度全满 | 检索能力 1/10、生命周期管理 2/10 |
| 6 | **supermemory** | **5.88** | 安装简单、资源占用低（云端） | 隐私 2/10（必须云端）|
| 7 | **cc-memory-arch** | **5.75** | 治理类 4 维全满（11–13 都 9 分）、隐私 / 部署满分 | 自动捕获 4、检索深度 2、benchmark 0、社区 1 |

---

### 解读

**MemPalace 凭检索精度（96.6% LongMemEval R@5）+ 数据模型 + 社区拿到第一**——这是值得尊敬的硬实力。

**cc-memory-arch 综合分倒数第一（5.75）**，原因是行业惯例权重把"自动捕获 + 检索能力 + 社区"加起来给了 ~40%，而本项目在这三块都低分（4/2/0/1）：
- 自动捕获 4：故意不做（非目标）
- 检索深度 2 / benchmark 0：故意不做（非目标）
- 社区 1：v1.0.x 刚发布，时间问题

**但综合分有局限**——它假设所有用户的 use case 同等加权。实际个人用户的需求是异质的：
- 你**已经**有 cc 原生 auto-memory 在用 → 自动捕获 / 检索能力对你的边际价值低（已经被覆盖）
- 你的痛点是 "MEMORY.md 长成杂物间 / 偏好被困在 per-cwd / 撤销时模型乱写" → 这正是治理类（C 区维度 11–13）和"跨项目共享"的弱项
- 此时**重新分配权重**：把 A 区降到 15%、C 区升到 35%、隐私 + 部署 + 社区 = 50%，结果会大不同

### 按"个人长期使用 cc"权重重算综合分

如果你**已经在用 cc + 痛点是 memory 治理而非检索**，权重重分配：A 15% / B 25% / C 40% / D 20%（社区降权，治理升权）。

| 排名 | 项目 | 个人治理权重综合分 |
|:-:|---|:-:|
| 🥇 1 | **cc-memory-arch** | **7.07** |
| 🥈 2 | MemPalace | 6.84 |
| 🥉 3 | claude-mem | 6.42 |
| 4 | memsearch | 6.13 |
| 5 | mem-compiler | 6.12 |
| 6 | cc 原生 | 5.80 |
| 7 | supermemory | 5.37 |

**结论**：综合分排第几不重要——看你的权重。本项目在 IR 行业惯例权重下排末位（5.75）是事实，在"个人 cc 治理痛点"权重下排第一（7.07）也是事实。看你的 use case 落在哪边。

> 加权计算方法、各权重小数值、Python 校验脚本：见 `scripts/score.py`（如需复现），或直接 issue 提出反对意见。

### 跟 cc 原生 auto-memory 的关系

cc-memory-arch **不替代** cc 原生 auto-memory，而是**修补 + 加纪律**：

| | cc 原生 | cc-memory-arch 增强 |
|---|---|---|
| 用户级偏好作用域 | per-cwd（换目录失效）| 上提到 USER.md / 全局 entry，真正全局 |
| 容量管理 | 仅 MEMORY.md 200 行硬截 | 分级容量上限 + 70% 触发 audit |
| 撤销语义 | 模型自由发挥（常写"不再 X"残留）| 单一不变量强制干净归零 |
| 路由判断 | 全部进 per-cwd | 4 层决策树 + recall 优先 |
| 强制层 | 无 | PreToolUse hook 拦截 |

装上后 cc 原生 auto-memory 仍然工作——只是写入路径被 mem-write skill 接管和路由。

## 调试

hook 调用日志写到 `/tmp/mem-write-hook.log`（每次 PreToolUse / PostToolUse 完整 event）。
怀疑分类不对时 `tail -f` 查证。
