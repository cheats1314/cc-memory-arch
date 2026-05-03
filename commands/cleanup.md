---
description: 卸载 cc-memory-arch 后清理残留（CLAUDE.md @-import / cc plugin 注册残留 / cache / marketplace）
allowed-tools: Bash, Read, Edit
---

# cc-memory-arch cleanup

`/plugin uninstall cc-memory-arch@cc-memory-arch` 之后跑一次，清理 cc 自身**不会**清的残留：

1. 撤销 `~/.claude/CLAUDE.md` 中的 `@memory/USER.md` 注入
2. 清 `~/.claude/settings.json` / `settings.local.json` 中残留的 `enabledPlugins["cc-memory-arch@cc-memory-arch"]`
3. 清 `~/.claude/plugins/cache/cc-memory-arch/` 孤立目录
4. （可选）`/plugin marketplace remove cc-memory-arch` —— 由用户在 cc 里手动跑，本命令不做

**保留**：`~/.claude/memory/`、`~/.claude/topics/` 下所有用户记忆数据。

## 执行步骤

### Step 0: 前置确认

提醒用户：本命令假设你**已经**跑过 `/plugin uninstall cc-memory-arch@cc-memory-arch --scope user`（或对应 scope）。如果还没卸载，先在 cc 里卸载，再跑本命令。

### Step 1: 撤销 CLAUDE.md @-import

Read `~/.claude/CLAUDE.md`：
- 若含 `@memory/USER.md` 这一行 → Edit 删掉这一行（精确匹配，不删其他 import）
- 不含 → 跳过

### Step 2: 清 enabledPlugins 残留

用 Bash 跑：

```bash
for f in ~/.claude/settings.json ~/.claude/settings.local.json; do
  [[ -f "$f" ]] || continue
  if jq -e '.enabledPlugins["cc-memory-arch@cc-memory-arch"] // false' "$f" >/dev/null 2>&1; then
    cp "$f" "$f.bak.$(date +%s)"
    jq 'del(.enabledPlugins["cc-memory-arch@cc-memory-arch"])
        | if .enabledPlugins == {} then del(.enabledPlugins) else . end' "$f" > "$f.tmp" \
      && mv "$f.tmp" "$f"
    echo "  ✓ 清掉 $f 中的 cc-memory-arch enabledPlugins（备份在 .bak.<ts>）"
  fi
done
```

### Step 3: 清 installed_plugins.json 残留条目

cc plugin uninstall 一般会清这条，但有时残留。用 Bash 检查：

```bash
F=~/.claude/plugins/installed_plugins.json
if [[ -f "$F" ]] && jq -e '.plugins["cc-memory-arch@cc-memory-arch"]' "$F" >/dev/null 2>&1; then
  cp "$F" "$F.bak.$(date +%s)"
  jq 'del(.plugins["cc-memory-arch@cc-memory-arch"])' "$F" > "$F.tmp" && mv "$F.tmp" "$F"
  echo "  ✓ 清掉 installed_plugins.json 中的 cc-memory-arch 条目"
fi
```

### Step 4: 清 cache 孤立目录

```bash
if [[ -d ~/.claude/plugins/cache/cc-memory-arch ]]; then
  rm -rf ~/.claude/plugins/cache/cc-memory-arch
  echo "  ✓ 清掉 ~/.claude/plugins/cache/cc-memory-arch/"
fi
```

### Step 5: 提示用户手动操作

报告以下后续动作（**不要**自动执行——marketplace 涉及 cc 内部状态）：

> 后续可选操作：
>
> - 完全断开 marketplace（不再接收更新）：在 cc 里跑 `/plugin marketplace remove cc-memory-arch`
> - 用户记忆数据保留在 `~/.claude/memory/` 和 `~/.claude/topics/`，未删除
> - 重启 cc 会话使 `enabledPlugins` 变更生效

## 报告格式

> ✅ cc-memory-arch cleanup 完成
>
> 已处理：
> - CLAUDE.md @-import：<删除 / 未发现>
> - settings.json enabledPlugins：<清理 / 未发现>
> - settings.local.json enabledPlugins：<清理 / 未发现>
> - installed_plugins.json：<清理 / 未发现>
> - cache 目录：<删除 / 未发现>
>
> 保留：~/.claude/memory/、~/.claude/topics/ 下所有数据
> 待你手动：/plugin marketplace remove cc-memory-arch（如不再用）
