---
name: mem-write
description: 写入或修改 ~/.claude/memory/、~/.claude/topics/、~/.claude/projects/*/memory/ 下任何文件前必须调用本 skill。本 skill 提供分类决策与目标路径。PreToolUse hook 会强制阻止未走本 skill 的写入。USER.md 由本 skill 自动管理（用户已授权改写）。
---

# mem-write

写入 memory 前先按下面决策树定位目标路径，再用 Write 工具写到该路径，并完成索引同步。

## 输入

- 待写入的内容（用户原话或你的总结）
- 当前 cwd
- 用户原始请求

## 决策原则（每次写入前必走，顺序不可跳）

### 原则 1：先读全局索引，主题归属优先于路径分类

**写入前必须 Read `~/.claude/memory/MEMORY.md`** 看有哪些已有 entries 及其描述。

判断新内容**主题**是否属于某既有 entry 的范围：
- 是 → **append/replace 到那个 entry**；同步 MEMORY.md 描述行（如有变化）；**跳过下面 Q1–Q4**
- 否 → 进入 Q1–Q4 决策树

**反例**："调用 dm-report agent 时不要覆盖路径"——这条属于已有 `feedback_report_preferences.md`（"调用 report agent 规范"）的子条款，必须 append 到那里，**不要**因为它"看起来像简短偏好"就塞进 USER.md。

### 原则 2：recall 到 entry 不等于无脑 append

若现有 entry 命中但**位于错误层**（例如本该在全局却在 per-cwd），先迁移整条再 append。

### 原则 3：去重

写入前 grep 待写入要点，已有等价条目则 replace，**不重复 append**。

### 原则 4：撤销 = 干净删（关键，最易踩坑）

用户撤销旧偏好时，必须**完全移除该条款**，**禁止以任何形式保留任何关于 X 的痕迹**。

**"任何形式"穷举**——以下所有变种都是错的，无一例外：

| ❌ 禁止的输出 | 含义但全错 |
|---|---|
| `... ，不再喜欢 X` | 否定式条款 |
| `... ，已不喜欢 X` | 时态否定 |
| `... ，曾经喜欢 X` | 历史标记 |
| `... ，不爱 X` | 否定情感 |
| `... ，已弃用 X` | 工程化措辞 |
| `... （已不喜欢 X）` | 括号注释否定 |
| `... （避免再加回 X）` | 防御性注释 |
| `... — 不再要 X` | 破折号注释 |
| 在 frontmatter description / 索引行里仍提及 X | 元数据残留 |

**正确**：直接把 X 从条款里抠掉，等同于这条 X 从未存在过。索引和 description 同步缩短。

不要担心"以后误加回来"——那是用户下次说"我又喜欢 X 了"时的事，不是你现在的责任。**保留任何否定痕迹 = 污染 = 被禁止**。

| 用户语义 | 触发词 | 动作 |
|---|---|---|
| **撤销**（无替代） | "我不 X 了 / 不再 X / 取消 X / 删 X / 别记 X / 忘掉 X" | 从条款剔除 X 全部痕迹；若整条 entry 变空 → 删文件 + 删索引 |
| **替换**（有替代） | "用 Y 不用 X / 改用 Y / X 改成 Y" | 把 X 替换为 Y |
| **新增** | "我喜欢 X / 加上 X" | append / 合并 |

**实例对照**：

| 用户原话 | 原条款 | ✓ 唯一正确 | ✗ 已知踩过的坑 |
|---|---|---|---|
| "我不爱吃辣了" | `喜欢吃辣，吃甜，吃零食` | `吃甜，吃零食` | `吃甜，吃零食（不再喜欢吃辣）` |
| "我现在不喜欢喝可乐了" | `吃甜，零食，爱喝可乐，吃汉堡` | `吃甜，零食，吃汉堡` | `吃甜，零食，吃汉堡（已不喜欢可乐）` |
| "别记我用 vim 了" | `编辑器：vim` | 删除整条 + 索引行 | `编辑器：~~vim~~` 或 `编辑器：（已弃用 vim）` |

## 决策树

### Q1：是否项目级（仅在当前 repo 内有意义）？

判据（**必须全部满足**）：
- 内容含**本仓库特有的**路径 / 命名 / 业务概念，**且**
- 换到其他 cwd 后此规则**完全失效或无意义**

仅"用户在某 cwd 下提到的偏好"**不**自动算项目级。
若内容是**工作流 / 工具 / agent 调用规范 / 跨项目通用习惯**，归 Q2，不要因为已有同名 per-cwd entry 就 append。

→ 写到 `~/.claude/projects/<cwd-hash>/memory/<entry>.md`
→ 同步更新该目录下 `MEMORY.md` 索引一行
→ 否则进入 Q2

### Q2：是否用户级 / 跨项目偏好？

涵盖：沟通风格 / 身份 / 工作流 / 工具习惯 / agent 使用约定 / 跨项目规则。
触发词："我喜欢 / 我习惯 / 我是 / 记住我 / 写 X 时怎么做 / 用某 agent / 调用某工具时…"

按内容形态二分：

**A. 简短偏好**（一两句、无规则细节）：
→ 写入 `~/.claude/memory/USER.md`。段位由你自行判断（身份 / 核心偏好 / 持久化记忆 / 新建段）。
→ 既有段已含等价条目 → **replace 而非追加**，保持 ≤ 80 行。

**B. 具体工作流 / 多条规则的偏好**（足以独立成 entry）：
→ 新建 `~/.claude/memory/<feedback_name>.md`，含 frontmatter (`name/description/type:feedback`)。
→ 在 `~/.claude/memory/MEMORY.md` 索引段加一行 `📚 <文件名> — <一句话描述>`。
→ **不写到 per-cwd**——本类偏好跨项目都成立。

→ 否则进入 Q3

### Q3：是否跨项目技术栈知识（Electron / MCP / CI / 特定工具坑）？

→ topic 已存在 → append 到 `~/.claude/topics/<topic>.md`
→ 不存在 → 新建 + 在 `~/.claude/CLAUDE.md` 的 topics 章节加一行索引
→ 否则进入 Q4

### Q4：不确定

→ 默认走项目级（cc 默认行为）
→ entry frontmatter 加 `unclear: true`，留待 /memory-audit 处理

## 写入后强制动作

1. **索引同步**
   - per-cwd → 更新对应 `~/.claude/projects/<hash>/memory/MEMORY.md`
   - topics → 更新 `~/.claude/CLAUDE.md` topics 段
   - USER.md → 自身即叶子，无需外部索引
2. **容量检查**（≥ 70% cap → 调 /memory-audit）
   - USER.md ≤ 80 行
   - 单 entry ≤ 80 行
   - topics/*.md ≤ 200 行
3. **去重**：写入前 grep 已有等价条目，有则 replace，没有再写

## frontmatter 格式（非 USER.md 条目）

```yaml
---
name: <短标题>
description: <一句话用途，用于 MEMORY.md 索引行>
type: feedback | project | reference | topic
---
```

USER.md 不需要 frontmatter。

## 输出给主 agent

- 目标绝对路径
- 应写入的最终文本（含 frontmatter 若需）
- 应同步更新的索引文件 + 那一行内容
