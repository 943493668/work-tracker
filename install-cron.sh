#!/bin/bash
# install-cron.sh - 安装 work-tracker SVN/Git 采集定时任务
# 运行一次即可：wsl bash ~/.config/opencode/skills/weekly-report/install-cron.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GIT_COLLECT="$HOME/.local/bin/work-tracker-git-collect.sh"
SVN_COLLECT="$HOME/.local/bin/work-tracker-svn-collect.sh"

echo "=== work-tracker cron 安装 ==="

# 确保采集脚本可执行
chmod +x "$GIT_COLLECT" "$SVN_COLLECT" 2>/dev/null || true

# 检查当前 crontab
CRONTAB_TMP=$(mktemp)
crontab -l > "$CRONTAB_TMP" 2>/dev/null || true

CRON_LINES=(
  "*/30 * * * * $GIT_COLLECT >> /tmp/work-tracker-git.log 2>&1"
  "*/30 8-23 * * * $SVN_COLLECT >> /tmp/work-tracker-svn.log 2>&1"
)

MODIFIED=0
for line in "${CRON_LINES[@]}"; do
  # 用脚本路径作为去重 key
  KEY=$(echo "$line" | sed 's|.*/work-tracker-\(git\|svn\)-collect\.sh.*|\1|')
  if ! grep -q "work-tracker-${KEY}-collect.sh" "$CRONTAB_TMP"; then
    echo "$line" >> "$CRONTAB_TMP"
    echo "  + 添加: ${KEY} cron"
    MODIFIED=1
  else
    echo "  = 已存在: ${KEY} cron"
  fi
done

if [ "$MODIFIED" = "1" ]; then
  crontab "$CRONTAB_TMP"
  echo ""
  echo "✅ cron 安装完成，当前条目："
  crontab -l
fi
rm -f "$CRONTAB_TMP"

# 同时安装 systemd 用户服务作为 cron 的备份（更可靠）
echo ""
echo "--- systemd 用户服务（备用，仅在 cron 不可用时启用）---"
echo "如需启用：systemctl --user enable --now work-tracker-collect.timer"

UNIT_DIR="$HOME/.config/systemd/user"
mkdir -p "$UNIT_DIR"

cat > "$UNIT_DIR/work-tracker-collect.service" <<UNIT
[Unit]
Description=work-tracker SVN+Git commit collector

[Service]
Type=oneshot
ExecStart=/bin/bash -c '[ -x "$GIT_COLLECT" ] && "$GIT_COLLECT"; [ -x "$SVN_COLLECT" ] && "$SVN_COLLECT"'
UNIT

cat > "$UNIT_DIR/work-tracker-collect.timer" <<UNIT
[Unit]
Description=Run work-tracker collector every 30 minutes

[Timer]
OnCalendar=*:00/30
Persistent=true
RandomizedDelaySec=60

[Install]
WantedBy=timers.target
UNIT

echo ""
echo "完成。如需立刻收集今天的提交，运行："
echo "  ~/.local/bin/work-tracker-backfill.sh 7"
