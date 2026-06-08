#!/bin/bash
# work-tracker-backfill.sh - 回填历史 Git/SVN 提交记录
# 用法: work-tracker-backfill.sh [天数，默认 30]
# 可重复运行，已存在的 commit/revision 不会重复写入

set -euo pipefail

DAYS=${1:-30}
INSTALL_DIR="$HOME/.local/share/work-tracker"
DAILY_DIR="$INSTALL_DIR/daily"
REPOS_FILE="$INSTALL_DIR/repos.txt"
SVN_REPOS_FILE="$INSTALL_DIR/svn-repos.txt"
USER=$(whoami)

mkdir -p "$DAILY_DIR"

echo "回填最近 ${DAYS} 天的提交记录..."
echo ""

TOTAL_GIT=0
TOTAL_SVN=0

if [ -f "$REPOS_FILE" ]; then
  echo "=== 扫描 Git 仓库 ==="
  while IFS= read -r repo || [ -n "$repo" ]; do
    [ -d "$repo/.git" ] || continue
    REPO_NAME=$(basename "$repo")
    BRANCH=$(git -C "$repo" branch --show-current 2>/dev/null || echo "unknown")
    echo "  → $REPO_NAME ($repo, branch: $BRANCH)"

    COUNT=0
    while IFS='|' read -r hash msg time_raw; do
      [ -n "$hash" ] || continue
      DATE=$(echo "$time_raw" | cut -d' ' -f1)
      DAILY_FILE="$DAILY_DIR/$DATE.json"

      if [ -f "$DAILY_FILE" ] && grep -q "\"hash\": \"${hash:0:7}\"" "$DAILY_FILE" 2>/dev/null; then
        continue
      fi

      if [ ! -f "$DAILY_FILE" ]; then
        echo "{\"date\": \"$DATE\", \"activities\": []}" > "$DAILY_FILE"
      fi

      STATS=$(git -C "$repo" diff --shortstat "${hash}^!" 2>/dev/null || echo "")
      FILES_CHANGED=$(echo "$STATS" | grep -oP '\d+(?= file)' || true)
      INSERTIONS=$(echo "$STATS" | grep -oP '\d+(?= insertion)' || true)
      DELETIONS=$(echo "$STATS" | grep -oP '\d+(?= deletion)' || true)
      FILES_CHANGED=${FILES_CHANGED:-0}
      INSERTIONS=${INSERTIONS:-0}
      DELETIONS=${DELETIONS:-0}

      TIME_FMT=$(date -d "$time_raw" +%Y-%m-%dT%H:%M:%S%z 2>/dev/null || echo "$time_raw")

      python3 - "$DAILY_FILE" "$TIME_FMT" "$REPO_NAME" "$BRANCH" "$USER" "$msg" \
        "$FILES_CHANGED" "$INSERTIONS" "$DELETIONS" "${hash:0:7}" <<'PYEOF'
import json, sys

daily_file, time_str, repo, branch, author, message = sys.argv[1:7]
files_changed, insertions, deletions, commit_hash = int(sys.argv[7]), int(sys.argv[8]), int(sys.argv[9]), sys.argv[10]

with open(daily_file, 'r') as f:
    data = json.load(f)

if commit_hash in {a.get('hash') for a in data['activities'] if a.get('type') == 'git_commit'}:
    sys.exit(0)

data['activities'].append({
    'type': 'git_commit', 'time': time_str, 'repo': repo, 'branch': branch,
    'author': author, 'message': message, 'files_changed': files_changed,
    'insertions': insertions, 'deletions': deletions, 'hash': commit_hash
})

with open(daily_file, 'w') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
PYEOF
      COUNT=$((COUNT + 1))
    done < <(git -C "$repo" log --author="$USER" --since="${DAYS} days ago" \
              --format="%H|%s|%ai" --no-merges 2>/dev/null || true)

    TOTAL_GIT=$((TOTAL_GIT + COUNT))
    echo "    +${COUNT} 条 git commit"
  done < "$REPOS_FILE"
  echo ""
fi

if [ -f "$SVN_REPOS_FILE" ]; then
  echo "=== 扫描 SVN 仓库 ==="
  while IFS= read -r repo || [ -n "$repo" ]; do
    [ -d "$repo/.svn" ] || continue
    REPO_NAME=$(basename "$repo")
    echo "  → $REPO_NAME ($repo)"

    SVN_INFO=$(svn info "$repo" 2>/dev/null || echo "")
    REPO_URL=$(echo "$SVN_INFO" | grep "^URL:" | head -1 | sed 's/URL: //' || echo "")
    SINCE_DATE=$(date -d "${DAYS} days ago" +%Y-%m-%dT00:00:00 2>/dev/null || date -v-${DAYS}d +%Y-%m-%dT00:00:00)

    SVN_LOG_FILE=$(mktemp)
    svn log "$repo" --xml -r "{${SINCE_DATE}}:HEAD" --search "$USER" > "$SVN_LOG_FILE" 2>/dev/null || true
    COUNT=$(python3 - "$SVN_LOG_FILE" "$DAILY_DIR" "$REPO_NAME" "$REPO_URL" "$repo" <<'PYEOF'
import json, sys, subprocess, os
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path

log_file, daily_dir, repo_name, repo_url, repo_path = sys.argv[1:6]

with open(log_file, 'r') as f:
    log_text = f.read()

if not log_text.strip():
    print(0)
    os.unlink(log_file)
    sys.exit(0)

try:
    root = ET.fromstring(log_text)
except Exception:
    print(0)
    os.unlink(log_file)
    sys.exit(0)

count = 0
for logentry in root.findall('logentry'):
    rev_num = int(logentry.get('revision', '0'))
    author_el = logentry.find('author')
    date_el = logentry.find('date')
    msg_el = logentry.find('msg')

    author = author_el.text if author_el is not None else ''
    if not author:
        continue

    date_raw = date_el.text if date_el is not None else ''
    if not date_raw:
        continue

    dt = datetime.fromisoformat(date_raw.replace('Z', '+00:00'))
    date_str = dt.strftime("%Y-%m-%d")
    time_str = dt.strftime("%Y-%m-%dT%H:%M:%S%z") or date_raw
    if time_str and time_str[-2:].isdigit() and time_str[-5] not in ('+', '-'):
        time_str = time_str[:-2] + '+' + time_str[-2:]

    msg = msg_el.text.strip() if msg_el is not None and msg_el.text else ''

    daily_file = os.path.join(daily_dir, f"{date_str}.json")
    if not os.path.exists(daily_file):
        with open(daily_file, 'w') as f:
            json.dump({"date": date_str, "activities": []}, f)

    with open(daily_file, 'r') as f:
        data = json.load(f)

    if rev_num in {a.get('revision') for a in data.get('activities', []) if a.get('type') == 'svn_commit'}:
        continue

    added = modified = deleted = files_count = 0
    try:
        diff_out = subprocess.run(
            ['svn', 'diff', '--summarize', '-c', f'r{rev_num}', repo_path],
            capture_output=True, text=True, timeout=15
        ).stdout
        files = [l for l in diff_out.splitlines() if l.strip()]
        added = sum(1 for l in files if l.startswith('A'))
        modified = sum(1 for l in files if l.startswith('M'))
        deleted = sum(1 for l in files if l.startswith('D'))
        files_count = len(files)
    except Exception:
        pass

    data['activities'].append({
        'type': 'svn_commit', 'time': time_str, 'repo': repo_name,
        'repo_url': repo_url, 'revision': rev_num, 'author': author,
        'message': msg, 'files_changed': files_count,
        'added': added, 'modified': modified, 'deleted': deleted
    })

    with open(daily_file, 'w') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    count += 1

print(count)
os.unlink(log_file)
PYEOF
    )
    rm -f "$SVN_LOG_FILE"
    TOTAL_SVN=$((TOTAL_SVN + COUNT))
    echo "    +${COUNT} 条 svn commit"
  done < "$SVN_REPOS_FILE"
  echo ""
fi

echo "=== 回填完成 ==="
echo "Git 提交: +${TOTAL_GIT} 条"
echo "SVN 提交: +${TOTAL_SVN} 条"
echo ""
echo "已生成的日志文件："
ls -lh "$DAILY_DIR"/ | grep -v "^total"
