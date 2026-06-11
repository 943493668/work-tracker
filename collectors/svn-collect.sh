#!/bin/bash
# svn-collect.sh - 扫描 svn-repos.txt 中的 SVN 仓库，收集最近 35 分钟的 commit
set -euo pipefail

INSTALL_DIR="$HOME/.local/share/work-tracker"
REPOS_FILE="$INSTALL_DIR/svn-repos.txt"
LOG_WRITER="$HOME/.local/bin/work-tracker-log-writer.sh"
TIMEOUT=10

[ -f "$REPOS_FILE" ] || exit 0
which svn >/dev/null 2>&1 || exit 0

USER=$(whoami)

while IFS= read -r repo || [ -n "$repo" ]; do
  [ -d "$repo/.svn" ] || continue
  REPO_NAME=$(basename "$repo")

  SVN_INFO=$(timeout $TIMEOUT svn info "$repo" 2>/dev/null) || continue
  REPO_URL=$(echo "$SVN_INFO" | grep "^URL:" | head -1 | sed 's/URL: //')

  SVN_LOG=$(timeout $TIMEOUT svn log "$repo" -r "BASE:HEAD" --quiet 2>/dev/null) || continue

  echo "$SVN_LOG" | grep "^r[0-9]" | tail -10 | while read -r line; do
    REV=$(echo "$line" | awk '{print $1}')
    AUTHOR=$(echo "$line" | awk '{print $3}')
    [ "$AUTHOR" = "$USER" ] || continue

    MSG=$(timeout $TIMEOUT svn log "$repo" -r "$REV" --quiet 2>/dev/null | sed '/^$/d' | sed -n '2p')
    MSG_ESC=$(printf '%s' "$MSG" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\r//g')

    DIFF_OUT=$(timeout $TIMEOUT svn diff --summarize -c "$REV" "$repo" 2>/dev/null || true)
    FILES=$(printf '%s\n' "$DIFF_OUT" | grep -cE '^[AMDRC]\s' || echo 0)
    ADDED=$(printf '%s\n' "$DIFF_OUT" | grep -c '^A' || echo 0)
    MODIFIED=$(printf '%s\n' "$DIFF_OUT" | grep -c '^M' || echo 0)
    DELETED=$(printf '%s\n' "$DIFF_OUT" | grep -c '^D' || echo 0)
    FILES=$(echo "$FILES" | tr -d '[:space:]'); FILES=${FILES:-0}
    ADDED=$(echo "$ADDED" | tr -d '[:space:]'); ADDED=${ADDED:-0}
    MODIFIED=$(echo "$MODIFIED" | tr -d '[:space:]'); MODIFIED=${MODIFIED:-0}
    DELETED=$(echo "$DELETED" | tr -d '[:space:]'); DELETED=${DELETED:-0}

    PAYLOAD="\"repo\": \"$REPO_NAME\", \"repo_url\": \"$REPO_URL\", \"revision\": ${REV#r}, \"author\": \"$AUTHOR\", \"message\": \"$MSG_ESC\", \"files_changed\": $FILES, \"added\": $ADDED, \"modified\": $MODIFIED, \"deleted\": $DELETED"

    "$LOG_WRITER" svn_commit "$PAYLOAD" 2>/dev/null
  done

done < "$REPOS_FILE"
