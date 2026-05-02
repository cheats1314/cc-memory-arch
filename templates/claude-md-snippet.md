## auto-memory 路由（cc-memory-arch plugin 接管）

写入 `~/.claude/memory/`、`~/.claude/topics/`、`~/.claude/projects/*/memory/` 下任何
非索引文件前，**必须先 invoke `mem-write` skill**。PreToolUse hook 会强制拦截。
USER.md 由 mem-write skill 自动管理（用户已授权改写）。

需要查全局 memory 还有哪些条目时，Read `~/.claude/memory/MEMORY.md`（默认不常驻）。
