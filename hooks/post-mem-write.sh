#!/usr/bin/env bash
set -euo pipefail
DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/lib.sh"

EVENT=$(cat)
LOG=/tmp/mem-write-hook.log
{
  echo "=== $(date -Iseconds) PostToolUse ==="
  echo "$EVENT" | jq . 2>/dev/null || echo "$EVENT"
} >> "$LOG"

FP=$(jq -r '.tool_input.file_path // ""' <<<"$EVENT")
CWD=$(jq -r '.cwd // ""' <<<"$EVENT")

# ~ 展开
[[ -n "$FP" && "$FP" == ~* ]] && FP="${FP/#\~/$HOME}"

if [[ -n "$FP" && "$FP" != /* ]]; then
  [[ -n "$CWD" ]] && FP="$CWD/$FP" || FP="$PWD/$FP"
fi

is_memory_path "$FP" || exit 0
[[ -f "$FP" ]] || exit 0

LINES=$(wc -l < "$FP" | tr -d ' ')
warn=""

case "$FP" in
  */USER.md)
    [[ "$LINES" -gt 64 ]] && warn="USER.md 当前 $LINES 行，已超 80% cap (80)。建议 /memory-audit。"
    ;;
  */topics/*.md)
    [[ "$LINES" -gt 160 ]] && warn="$(basename "$FP") 当前 $LINES 行，已超 80% cap (200)。建议拆 sub-topic。"
    ;;
  */memory/*.md|*/projects/*/memory/*.md)
    [[ "$LINES" -gt 64 ]] && warn="$(basename "$FP") 当前 $LINES 行，已超 80% cap (80)。建议精简或拆分。"
    ;;
esac

[[ -n "$warn" ]] && echo "[post-mem-audit] $warn" >&2

# 索引同步检查
case "$FP" in
  "$HOME/.claude/projects/"*"/memory/"*)
    DIR_OF=$(dirname "$FP")
    BASE=$(basename "$FP")
    if [[ "$BASE" != "MEMORY.md" ]] && [[ -f "$DIR_OF/MEMORY.md" ]]; then
      grep -qF "$BASE" "$DIR_OF/MEMORY.md" \
        || echo "[post-mem-audit] $BASE 已写入但未在 $DIR_OF/MEMORY.md 索引中。请同步。" >&2
    fi
    ;;
esac

exit 0
