#!/usr/bin/env bash
set -euo pipefail
TARGET="$HOME/.claude/plugins/cc-memory-arch"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
SETTINGS="$HOME/.claude/settings.json"
IMPORT_LINE="@$HOME/.claude/plugins/cc-memory-arch/templates/claude-md-snippet.md"

# 删 @-import 行
if [[ -f "$CLAUDE_MD" ]] && grep -qF "$IMPORT_LINE" "$CLAUDE_MD"; then
  cp "$CLAUDE_MD" "$CLAUDE_MD.bak"
  grep -vF "$IMPORT_LINE" "$CLAUDE_MD.bak" > "$CLAUDE_MD" || true
  echo "  ✓ 已从 ~/.claude/CLAUDE.md 移除 @-import（备份在 .bak）"
fi

# 同步清理 settings.json / settings.local.json 中的 cc-memory-arch hooks
strip_hooks() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  grep -qF "cc-memory-arch" "$f" || return 0
  cp "$f" "$f.bak.$(date +%s)"
  jq '
    if .hooks.PreToolUse  then .hooks.PreToolUse  |= map(select((.hooks // []) | map(.command // "" | contains("cc-memory-arch")) | any | not)) else . end |
    if .hooks.PostToolUse then .hooks.PostToolUse |= map(select((.hooks // []) | map(.command // "" | contains("cc-memory-arch")) | any | not)) else . end |
    if (.hooks // {}) == {} then del(.hooks) else . end
  ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  echo "  ✓ 已从 $f 移除 cc-memory-arch hooks（备份在 .bak.<timestamp>）"
}

strip_hooks "$HOME/.claude/settings.local.json"
strip_hooks "$SETTINGS"

# 删 plugin 软链
if [[ -L "$TARGET" || -e "$TARGET" ]]; then
  rm -rf "$TARGET"
  echo "  ✓ 已删除 $TARGET"
fi

# 删 skill（兼容旧版软链与新版 cp 真目录）
SKILL_TARGET="$HOME/.claude/skills/mem-write"
if [[ -L "$SKILL_TARGET" || -e "$SKILL_TARGET" ]]; then
  rm -rf "$SKILL_TARGET"
  echo "  ✓ 已删除 $SKILL_TARGET"
fi

cat <<EOF

✅ cc-memory-arch 已卸载
   memory/ 数据保留：~/.claude/memory/、~/.claude/topics/
   重启 cc 会话生效
EOF
