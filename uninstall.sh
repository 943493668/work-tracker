#!/bin/bash

echo "卸载 Work Tracker..."

crontab -l 2>/dev/null | grep -v "work-tracker" | crontab -

rm -rf "$HOME/.local/share/work-tracker"
rm -rf "$HOME/.config/opencode/skills/weekly-report"
rm -f  "$HOME/.local/bin/work-tracker-git-collect.sh"
rm -f  "$HOME/.local/bin/work-tracker-svn-collect.sh"
rm -f  "$HOME/.local/bin/work-tracker-log-writer.sh"

WIN_USER_DIR="/mnt/c/Users/$USERNAME"
if grep -qi microsoft /proc/version 2>/dev/null && [ -d "$WIN_USER_DIR" ]; then
  rm -rf "$WIN_USER_DIR/.config/opencode/skills/weekly-report"
fi

echo "✓ Cron 任务已移除"
echo "✓ 脚本和 skill 已删除"
echo ""
echo "如需移除 ~/.bashrc 中的 shell 钩子，请手动删除包含 work-tracker 的行"
echo "然后执行: source ~/.bashrc"
