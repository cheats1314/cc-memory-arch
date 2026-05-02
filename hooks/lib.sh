#!/usr/bin/env bash
# 共享工具函数

is_memory_path() {
  local p="$1"
  case "$p" in
    "$HOME/.claude/memory/"*|"$HOME/.claude/topics/"*|"$HOME/.claude/projects/"*"/memory/"*) return 0 ;;
    *) return 1 ;;
  esac
}

is_index_file() {
  [[ "$1" == *MEMORY.md ]]
}

# 检测最近 transcript 是否激活过 mem-write skill
recent_skill_active() {
  local transcript="$1"
  [[ -f "$transcript" ]] || return 1
  tail -300 "$transcript" 2>/dev/null \
    | grep -qE '"(skill|skill_name|name)":[[:space:]]*"mem-write"'
}
