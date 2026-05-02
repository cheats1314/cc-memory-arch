#!/usr/bin/env bash
set -euo pipefail
PLUGIN_DIR=$(cd "$(dirname "$0")" && pwd)
TARGET="$HOME/.claude/plugins/cc-memory-arch"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
IMPORT_LINE="@$HOME/.claude/plugins/cc-memory-arch/templates/claude-md-snippet.md"

mkdir -p "$HOME/.claude/plugins" "$HOME/.claude/memory" "$HOME/.claude/topics" "$HOME/.claude/skills"

# 真安装 plugin（cp -r）：与源目录解耦，源目录可删/可移而不影响
if [[ -L "$TARGET" || -e "$TARGET" ]]; then
  rm -rf "$TARGET"
fi
cp -r "$PLUGIN_DIR" "$TARGET"
chmod +x "$TARGET/hooks/"*.sh
chmod +x "$TARGET/install.sh" "$TARGET/uninstall.sh"
echo "  ✓ plugin 安装：$TARGET（独立副本）"

# 真安装 skill 到 cc 默认扫描位置（cc 不会扫 plugin 内 skills/）
SKILL_TARGET="$HOME/.claude/skills/mem-write"
if [[ -L "$SKILL_TARGET" || -e "$SKILL_TARGET" ]]; then
  rm -rf "$SKILL_TARGET"
fi
cp -r "$PLUGIN_DIR/skills/mem-write" "$SKILL_TARGET"
echo "  ✓ skill 安装：$SKILL_TARGET（独立副本）"

# 注入 CLAUDE.md @-import（幂等）
touch "$CLAUDE_MD"
if ! grep -qF "$IMPORT_LINE" "$CLAUDE_MD"; then
  printf '\n%s\n' "$IMPORT_LINE" >> "$CLAUDE_MD"
  echo "  ✓ 已注入 @-import 到 ~/.claude/CLAUDE.md"
else
  echo "  ✓ ~/.claude/CLAUDE.md 已含 @-import，跳过"
fi

# 初始化 USER.md（如果不存在）
USER_MD="$HOME/.claude/memory/USER.md"
if [[ ! -f "$USER_MD" ]]; then
  cat > "$USER_MD" <<'EOF'
# USER.md

> 用户身份 + 核心偏好 + 显式希望持久化的内容。由 mem-write skill 自动管理（用户已授权改写）。
> 容量上限 ≤ 80 行。

## 身份

<!-- 例如：X 方向研究 / 工作；当前主要做 Y -->

## 核心偏好

<!-- 例如：沟通语言 / 回答长度 / 是否要末尾总结 / 工具偏好 -->

## 持久化记忆

<!-- 用户主动要求"记一下"但还没单独抽 entry 的内容暂存这里 -->
EOF
  echo "  ✓ 已初始化 ~/.claude/memory/USER.md"
else
  echo "  ✓ ~/.claude/memory/USER.md 已存在，保留原内容"
fi

# 初始化 ~/.claude/memory/MEMORY.md（如果不存在）
GLOBAL_MEMORY_MD="$HOME/.claude/memory/MEMORY.md"
if [[ ! -f "$GLOBAL_MEMORY_MD" ]]; then
  cat > "$GLOBAL_MEMORY_MD" <<'EOF'
# 全局记忆索引

> 由 mem-write skill 维护。
> ⚡ USER.md 通过 ~/.claude/CLAUDE.md 的 `@memory/USER.md` 常驻；其他全部 📚 按需 Read。
> 容量上限 30 entries。

## 索引

⚡ USER.md — 用户身份 / 核心偏好
EOF
  echo "  ✓ 已初始化 ~/.claude/memory/MEMORY.md"
fi

# 替换 CLAUDE.md 中过时的 @memory/MEMORY.md → @memory/USER.md（如存在）
if grep -qF "@memory/MEMORY.md" "$CLAUDE_MD"; then
  sed -i.bak "s|@memory/MEMORY.md|@memory/USER.md|" "$CLAUDE_MD"
  echo "  ✓ ~/.claude/CLAUDE.md 顶部 import 已切到 @memory/USER.md（备份在 .bak）"
fi

# 注册 hooks 到 settings.local.json（避免污染共享的 settings.json）
LOCAL="$HOME/.claude/settings.local.json"
PRE_CMD="$TARGET/hooks/pre-mem-write.sh"
POST_CMD="$TARGET/hooks/post-mem-write.sh"

if [[ ! -f "$LOCAL" ]]; then
  echo '{}' > "$LOCAL"
fi

if ! grep -qF "cc-memory-arch" "$LOCAL"; then
  cp "$LOCAL" "$LOCAL.bak.$(date +%s)"
  jq --arg pre "$PRE_CMD" --arg post "$POST_CMD" '
    .hooks //= {} |
    .hooks.PreToolUse  = ((.hooks.PreToolUse  // []) + [{matcher:"Write|Edit|MultiEdit", hooks:[{type:"command", command:$pre}]}]) |
    .hooks.PostToolUse = ((.hooks.PostToolUse // []) + [{matcher:"Write|Edit|MultiEdit", hooks:[{type:"command", command:$post}]}])
  ' "$LOCAL" > "$LOCAL.tmp" && mv "$LOCAL.tmp" "$LOCAL"
  echo "  ✓ 已合并 hooks 到 $LOCAL（备份在 .bak.<timestamp>）"
else
  echo "  ✓ $LOCAL 已含 cc-memory-arch hooks，跳过"
fi

cat <<EOF

✅ cc-memory-arch 安装完成
   plugin: $TARGET
   重启 cc 会话生效

升级：在源仓库目录里 \`git pull && ./install.sh\` 重跑即可。
卸载：\`$TARGET/uninstall.sh\`

测试用例（在新会话里依次说）：
  1. "记住我喜欢干练的语言"          → 期望进 ~/.claude/memory/USER.md
  2. "记一下本项目的 build 命令是 X" → 期望进 ~/.claude/projects/<hash>/memory/
  3. "Electron 重建模块用 npm rebuild" → 期望进 ~/.claude/topics/electron.md
EOF
