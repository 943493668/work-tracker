#!/bin/bash
# log-writer.sh - 统一日志写入器，所有采集脚本共用
# 用法: log-writer.sh <type> <json_payload>
#   type: git_commit | svn_commit | shell_command | file_change
#   json_payload: JSON 字符串（不含 type 和 time 字段）

set -euo pipefail

INSTALL_DIR="$HOME/.local/share/work-tracker"
DAILY_DIR="$INSTALL_DIR/daily"
TODAY=$(date +%Y-%m-%d)
DAILY_FILE="$DAILY_DIR/$TODAY.json"

TYPE="${1:?usage: log-writer.sh <type> <json_payload>}"
PAYLOAD="${2:?usage: log-writer.sh <type> <json_payload>}"

mkdir -p "$DAILY_DIR"

LOCK_FILE="$DAILY_DIR/.lock"
ENTRY_FILE=$(mktemp)
trap "rm -f '$ENTRY_FILE'" EXIT

TIME=$(date +%Y-%m-%dT%H:%M:%S%z)
printf '%s' "{\"type\": \"$TYPE\", \"time\": \"$TIME\", $PAYLOAD}" > "$ENTRY_FILE"

(
  flock -w 10 200 || exit 1

  if [ ! -f "$DAILY_FILE" ]; then
    echo "{\"date\": \"$TODAY\", \"activities\": []}" > "$DAILY_FILE"
  fi

  python3 - "$DAILY_FILE" "$ENTRY_FILE" <<'PYEOF'
import json, sys

daily_file = sys.argv[1]
entry_file = sys.argv[2]

with open(daily_file, 'r') as f:
    data = json.load(f)

with open(entry_file, 'r') as f:
    entry = json.load(f)

data['activities'].append(entry)

with open(daily_file, 'w') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
PYEOF
) 200>"$LOCK_FILE"
