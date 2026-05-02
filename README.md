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

## 与其他 memory 项目的关系

| | claude-mem | MemPalace | memsearch | cc-memory-arch |
|---|---|---|---|---|
| 自动捕获 | ✅ | ✅ | ✅ | ❌（手动 / agent） |
| 语义检索 | ✅ 向量 | ✅ 向量 | ✅ Milvus | ❌ |
| 基础设施 | SQLite+Chroma | Chroma+SQLite | Milvus | **零** |
| 主动 curation | ❌ | ❌ | ❌ | ✅ |
| 跨项目共享路由 | — | — | — | ✅（USER.md / 全局 / topics）|
| 分类强制点 | — | — | — | hook + skill（不靠 prompt 信仰）|

不与上述项目竞争"装得多"，专注"装得对"+ "防膨胀"。

## 调试

hook 调用日志写到 `/tmp/mem-write-hook.log`（每次 PreToolUse / PostToolUse 完整 event）。
怀疑分类不对时 `tail -f` 查证。
