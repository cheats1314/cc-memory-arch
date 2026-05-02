#!/usr/bin/env bash
set -euo pipefail
DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/lib.sh"

EVENT=$(cat)
LOG=/tmp/mem-write-hook.log
{
  echo "=== $(date -Iseconds) PreToolUse ==="
  echo "$EVENT" | jq . 2>/dev/null || echo "$EVENT"
} >> "$LOG"

FP=$(jq -r '.tool_input.file_path // ""' <<<"$EVENT")
CWD=$(jq -r '.cwd // ""' <<<"$EVENT")
TRANSCRIPT=$(jq -r '.transcript_path // ""' <<<"$EVENT")

# 相对路径 → 绝对路径
if [[ -n "$FP" && "$FP" != /* ]]; then
  if [[ -n "$CWD" ]]; then
    FP="$CWD/$FP"
  else
    FP="$PWD/$FP"
  fi
fi
echo "resolved FP=$FP" >> "$LOG"

is_memory_path "$FP" || exit 0
is_index_file "$FP" && exit 0
recent_skill_active "$TRANSCRIPT" && exit 0

cat >&2 <<EOF
[mem-write-guard] 拒绝直接写入 memory 文件：
  $FP

按 cc-memory-arch 规范，写入 ~/.claude/memory/、~/.claude/topics/、
~/.claude/projects/*/memory/ 下任何非 MEMORY.md 文件前，必须先 invoke mem-write skill。

操作：
  1. 调用 mem-write skill，提交待写入内容
  2. 按 skill 返回的目标路径与文本写入
EOF
exit 2
