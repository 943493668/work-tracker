#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.local/share/work-tracker"
BIN_DIR="$HOME/.local/bin"

echo "╔═══════════════════════════════════════╗"
echo "║   Work Tracker - 轻量版周报生成工具  ║"
echo "╚═══════════════════════════════════════╝"
echo ""

if [ "$1" = "lite" ]; then
  MODE="lite"
elif [ "$1" = "full" ]; then
  MODE="full"
else
  echo "请选择安装模式："
  echo "  1) lite  - 仅 Git + SVN 追踪（最小化，无 Shell 记录）"
  echo "  2) full  - Git + SVN + Shell 命令追踪（推荐）"
  echo ""
  read -p "输入选择 [1/2，默认 2]: " choice
  MODE=$( [ "$choice" = "1" ] && echo "lite" || echo "full" )
fi

echo "安装模式: $MODE"
echo ""

mkdir -p "$INSTALL_DIR/daily" "$BIN_DIR"

cp "$SCRIPT_DIR/collectors/log-writer.sh"  "$BIN_DIR/work-tracker-log-writer.sh"
cp "$SCRIPT_DIR/collectors/git-collect.sh" "$BIN_DIR/work-tracker-git-collect.sh"
cp "$SCRIPT_DIR/collectors/svn-collect.sh" "$BIN_DIR/work-tracker-svn-collect.sh"
cp "$SCRIPT_DIR/collectors/backfill.sh"    "$BIN_DIR/work-tracker-backfill.sh"

chmod +x "$BIN_DIR"/work-tracker-*.sh

if [ ! -f "$INSTALL_DIR/config.json" ]; then
  cp "$SCRIPT_DIR/config.json" "$INSTALL_DIR/config.json"
fi

touch "$INSTALL_DIR/repos.txt" "$INSTALL_DIR/svn-repos.txt"

echo "安装 cron 任务（Git 每整点，SVN 每整点后5分钟）..."
(crontab -l 2>/dev/null | grep -v "work-tracker-git-collect\|work-tracker-svn-collect"; \
 echo "0 * * * * $BIN_DIR/work-tracker-git-collect.sh"; \
 echo "5 * * * * $BIN_DIR/work-tracker-svn-collect.sh") | crontab -

echo "检测 opencode 运行环境..."
WIN_USER_DIR="/mnt/c/Users/$USERNAME"
if grep -qi microsoft /proc/version 2>/dev/null && [ -d "$WIN_USER_DIR" ]; then
  OC_BIN=$(which opencode 2>/dev/null)
  if echo "$OC_BIN" | grep -q "/mnt/c/" 2>/dev/null; then
    echo "✓ 检测到 WSL 环境 + Windows opencode 二进制，skill 安装到 Windows 侧"
    SKILL_DIR="$WIN_USER_DIR/.config/opencode/skills/weekly-report"
  else
    SKILL_DIR="$HOME/.config/opencode/skills/weekly-report"
  fi
else
  SKILL_DIR="$HOME/.config/opencode/skills/weekly-report"
fi
mkdir -p "$SKILL_DIR"
cp "$SCRIPT_DIR/SKILL.md"    "$SKILL_DIR/SKILL.md"
cp "$SCRIPT_DIR/reporter.py" "$SKILL_DIR/reporter.py"
cp "$SCRIPT_DIR/reporter.py" "$INSTALL_DIR/reporter.py"
echo "✓ opencode Skill 安装到 $SKILL_DIR"

echo "检测其他 AI 工具..."
TOOLS_INSTALLED=0

# Cursor
if command -v cursor >/dev/null 2>&1 || [ -d "$HOME/.cursor" ]; then
  CURSOR_RULES_DIR="$HOME/.cursor/rules"
  mkdir -p "$CURSOR_RULES_DIR"
  cp "$SCRIPT_DIR/templates/cursor-rule.md" "$CURSOR_RULES_DIR/work-tracker.md"
  echo "✓ Cursor 规则安装到 $CURSOR_RULES_DIR/work-tracker.md"
  TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
fi

# Claude Code / OpenAI Codex
if command -v claude >/dev/null 2>&1 || [ -d "$HOME/.claude" ]; then
  CLAUDE_DIR="$HOME/.claude"
  mkdir -p "$CLAUDE_DIR"
  cp "$SCRIPT_DIR/templates/AGENTS.md" "$CLAUDE_DIR/AGENTS.md"
  echo "✓ Claude Code AGENTS.md 安装到 $CLAUDE_DIR/AGENTS.md"
  TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
fi

# Windsurf
if [ -d "$HOME/.codeium" ] || command -v windsurf >/dev/null 2>&1; then
  cp "$SCRIPT_DIR/templates/cursor-rule.md" "$HOME/.windsurfrules" 2>/dev/null || true
  echo "✓ Windsurf 规则安装到 ~/.windsurfrules"
  TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
fi

if [ -f "$HOME/.bashrc" ] && [ "$MODE" = "full" ]; then
  if ! grep -q "work-tracker/shell-hook" "$HOME/.bashrc" 2>/dev/null; then
    echo '[ -f "$HOME/.local/share/work-tracker/shell-hook.sh" ] && source "$HOME/.local/share/work-tracker/shell-hook.sh"' >> "$HOME/.bashrc"
    cp "$SCRIPT_DIR/shell-hook.sh" "$INSTALL_DIR/shell-hook.sh"
    echo "✓ Shell 钩子已安装到 ~/.bashrc（重启终端生效）"
  else
    echo "✓ Shell 钩子已存在，跳过"
  fi
fi

echo "扫描 Git 仓库..."
GIT_COUNT=0
find "$HOME" -name ".git" -type d -maxdepth 5 2>/dev/null | while read -r gitdir; do
  repo=$(dirname "$gitdir")
  if ! grep -qxF "$repo" "$INSTALL_DIR/repos.txt" 2>/dev/null; then
    echo "$repo" >> "$INSTALL_DIR/repos.txt"
    GIT_COUNT=$((GIT_COUNT + 1))
  fi
done

echo "扫描 SVN 仓库..."
SVN_COUNT=0
find "$HOME" -name ".svn" -type d -maxdepth 5 2>/dev/null | while read -r svndir; do
  repo=$(dirname "$svndir")
  if ! grep -qxF "$repo" "$INSTALL_DIR/svn-repos.txt" 2>/dev/null; then
    echo "$repo" >> "$INSTALL_DIR/svn-repos.txt"
    SVN_COUNT=$((SVN_COUNT + 1))
  fi
done

GIT_TOTAL=$(wc -l < "$INSTALL_DIR/repos.txt" | tr -d ' ')
SVN_TOTAL=$(wc -l < "$INSTALL_DIR/svn-repos.txt" | tr -d ' ')

echo ""
echo "╔═══════════════════════════════════════╗"
echo "║           安装完成！                  ║"
echo "╚═══════════════════════════════════════╝"
echo ""
echo "  Git 仓库: ${GIT_TOTAL} 个"
echo "  SVN 仓库: ${SVN_TOTAL} 个"
echo "  模式:     $MODE"
echo ""
echo "使用方式："
echo "  在 opencode 中输入 \"生成周报\" → concise 精简模式"
echo "  在 opencode 中输入 \"生成详细周报\" → detailed 详细模式"
echo "  在 Cursor/Claude Code 中输入 \"生成周报\" 同样可用"
echo ""
echo "手动运行：python3 ~/.local/share/work-tracker/reporter.py"
echo ""
echo "首次使用建议运行回填命令以获取历史记录："
echo "  ~/.local/bin/work-tracker-backfill.sh 30"
