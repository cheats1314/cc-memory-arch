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
# 兼容两种 skill 标识：
#   - 用户级 skill: "mem-write"
#   - plugin 内 skill: "cc-memory-arch:mem-write"（cc 加 plugin 前缀）
recent_skill_active() {
  local transcript="$1"
  [[ -f "$transcript" ]] || return 1
  tail -300 "$transcript" 2>/dev/null \
    | grep -qE '"(skill|skill_name|name)":[[:space:]]*"[^"]*mem-write"'
}
