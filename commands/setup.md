---
description: 初始化 cc-memory-arch 用户侧资源（USER.md / MEMORY.md / CLAUDE.md @-import），幂等
allowed-tools: Bash, Read, Edit, Write
---

# cc-memory-arch setup

用户首次启用本 plugin 后跑一次。本命令完成 plugin 自身**无法**通过 cc plugin 协议完成的"用户侧"一次性配置：

1. 确保 `~/.claude/memory/USER.md` 存在
2. 确保 `~/.claude/memory/MEMORY.md` 存在
3. 在 `~/.claude/CLAUDE.md` 中注入 `@memory/USER.md` import（如尚未注入）

所有动作都是**幂等**的——已存在则跳过，不覆盖用户既有内容。

## 执行步骤

### Step 1: 读现状

按下面顺序 Read 每个文件，记录是否存在：

- `~/.claude/CLAUDE.md`
- `~/.claude/memory/USER.md`
- `~/.claude/memory/MEMORY.md`

### Step 2: 创建缺失的资源

#### 2.1 USER.md（如不存在则 Write 创建）

路径：`~/.claude/memory/USER.md`

内容：

```markdown
# USER.md

> 用户身份 + 核心偏好 + 显式希望持久化的内容。由 mem-write skill 自动管理（用户已授权改写）。
> 容量上限 ≤ 80 行。

## 身份

<!-- 例如：X 方向研究 / 工作；当前主要做 Y -->

## 核心偏好

<!-- 例如：沟通语言 / 回答长度 / 是否要末尾总结 / 工具偏好 -->

## 持久化记忆

<!-- 用户主动要求"记一下"但还没单独抽 entry 的内容暂存这里 -->
```

如果 `~/.claude/memory/` 目录不存在，先用 Bash 创建：`mkdir -p ~/.claude/memory`。

#### 2.2 MEMORY.md（如不存在则 Write 创建）

路径：`~/.claude/memory/MEMORY.md`

内容：

```markdown
# 全局记忆索引

> 由 mem-write skill 维护。
> ⚡ USER.md 通过 ~/.claude/CLAUDE.md 的 `@memory/USER.md` 常驻；其他全部 📚 按需 Read。
> 容量上限 30 entries。

## 索引

⚡ USER.md — 用户身份 / 核心偏好
```

### Step 3: 注入 CLAUDE.md @-import（关键）

读 `~/.claude/CLAUDE.md`：

- **若文件不存在**：Write 创建，内容仅一行：`@memory/USER.md`
- **若文件存在但已含 `@memory/USER.md`**：跳过（已注入）
- **若文件存在但含已废弃的 `@memory/MEMORY.md`**：用 Edit 把 `@memory/MEMORY.md` 替换为 `@memory/USER.md`
- **以上都不满足**：用 Edit 在文件**末尾**追加一空行 + `@memory/USER.md`

注意：不要用 Bash 的 `echo >>` 直接追加；先 Read 全文再决定动作。

### Step 4: 校验并报告

执行后用 Bash 跑一次校验并把结果回报给用户：

```bash
echo "=== USER.md ==="
test -f ~/.claude/memory/USER.md && wc -l ~/.claude/memory/USER.md || echo "缺失"
echo "=== MEMORY.md ==="
test -f ~/.claude/memory/MEMORY.md && wc -l ~/.claude/memory/MEMORY.md || echo "缺失"
echo "=== CLAUDE.md @-import ==="
grep -nF '@memory/USER.md' ~/.claude/CLAUDE.md || echo "未注入"
```

报告格式（给用户）：

> ✅ cc-memory-arch setup 完成
>
> - USER.md：<新建 / 已存在 N 行>
> - MEMORY.md：<新建 / 已存在 N 行>
> - CLAUDE.md @-import：<新建注入 / 替换旧 MEMORY.md import / 已存在 / 末尾追加>
>
> 重启 cc 会话使 `@memory/USER.md` 生效。

## 撤销

需要撤销时跑 `/cc-memory-arch:cleanup`。注意 cleanup 不会删 USER.md / MEMORY.md 数据本身——只会撤销 CLAUDE.md @-import 行。
