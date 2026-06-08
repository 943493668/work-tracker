#!/bin/bash
# shell-hook.sh - 记录用户执行的 Shell 命令（source 到 ~/.bashrc 中）
# 通过 PROMPT_COMMAND 钩子触发，使用 log-writer.sh 统一写入

__wt_record_cmd() {
  local IGNORE_CMDS="cd|ls|ll|la|pwd|clear|exit|history|top|htop|neofetch"
  local cmd

  cmd=$(history 1 | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//')

  [ -n "$cmd" ] || return
  [ "${cmd:0:1}" != " " ] || return

  local first_word
  first_word=$(echo "$cmd" | awk '{print $1}')
  echo "$first_word" | grep -qE "^($IGNORE_CMDS)$" && return

  local LOG_WRITER="$HOME/.local/bin/work-tracker-log-writer.sh"
  [ -x "$LOG_WRITER" ] || return

  local cmd_esc cwd_esc payload
  # 通过 python 安全转义，避免 shell 特殊字符破坏 JSON
  payload=$(python3 -c "
import json, sys
payload = {'command': sys.argv[1], 'cwd': sys.argv[2], 'exit_code': int(sys.argv[3])}
# 输出去掉外层 {} 的内容
items = ', '.join(f'\"{k}\": {json.dumps(v)}' for k, v in payload.items())
print(items)
" "$cmd" "$(pwd)" "$?" 2>/dev/null) || return

  "$LOG_WRITER" shell_command "$payload" 2>/dev/null &
}

PROMPT_COMMAND="__wt_record_cmd; $PROMPT_COMMAND"
