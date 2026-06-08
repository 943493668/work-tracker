#!/bin/bash
# git-collect.sh - 扫描 repos.txt 中的 Git 仓库，收集最近 30 分钟的 commit
set -euo pipefail

INSTALL_DIR="$HOME/.local/share/work-tracker"
REPOS_FILE="$INSTALL_DIR/repos.txt"
LOG_WRITER="$HOME/.local/bin/work-tracker-log-writer.sh"

[ -f "$REPOS_FILE" ] || exit 0

while IFS= read -r repo || [ -n "$repo" ]; do
  [ -d "$repo/.git" ] || continue
  REPO_NAME=$(basename "$repo")
  BRANCH=$(git -C "$repo" branch --show-current 2>/dev/null || echo "unknown")

  git -C "$repo" log --author="$(whoami)" --since="35 minutes ago" --format="%H|%s|%ai" --no-merges 2>/dev/null | while IFS='|' read -r hash msg time; do
    [ -n "$hash" ] || continue

    STATS=$(git -C "$repo" diff --shortstat "${hash}^!" 2>/dev/null || echo "")
    FILES_CHANGED=$(echo "$STATS" | grep -oP '\d+(?= file)' || echo "0")
    INSERTIONS=$(echo "$STATS" | grep -oP '\d+(?= insertion)' || echo "0")
    DELETIONS=$(echo "$STATS" | grep -oP '\d+(?= deletion)' || echo "0")

    MSG_ESC=$(echo "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g')
    PAYLOAD="\"repo\": \"$REPO_NAME\", \"branch\": \"$BRANCH\", \"author\": \"$(whoami)\", \"message\": \"$MSG_ESC\", \"files_changed\": $FILES_CHANGED, \"insertions\": $INSERTIONS, \"deletions\": $DELETIONS, \"hash\": \"${hash:0:7}\""

    "$LOG_WRITER" git_commit "$PAYLOAD" 2>/dev/null
  done

done < "$REPOS_FILE"
