# Work Tracker

跨工具工作活动追踪与周报生成工具。自动采集 Git、SVN、Shell 命令和 opencode 对话记录，一键生成精简周报。

## 为什么用它

还在为写周报翻聊天记录、查 Git log 而头疼？Work Tracker 帮你自动化这个过程。

**做什么：** 后台静默采集你的日常开发活动 —— Git commit、SVN commit、终端命令、opencode 对话 —— 统一写入 JSON 日志（每日 ~50KB）。

**怎么用：** 在 opencode 输入"生成周报"，即可按项目分组输出精简摘要（concise，适合上交）或详细复盘（detailed，适合团队 review）。Cursor / Claude Code / Windsurf 用户只需把 rules 文件放到对应目录同样触发。

**特点：** 零依赖（不需要 sudo 或装第三方库）、零常驻（无 systemd/inotifywait）、全本地存储、支持 WSL + Windows opencode 混合环境。别人 clone 后一条 `bash install.sh` 就能用。

## 功能

- **Git 提交追踪** — 每小时自动扫描本地 Git 仓库的 commit
- **SVN 提交追踪** — 每小时自动扫描本地 SVN 仓库的 commit
- **Shell 命令记录** — 通过 bash 钩子记录终端命令（full 模式）
- **opencode 对话** — 实时读取 opencode 聊天记录
- **两种周报模式** — concise（精简，5-15字/条）或 detailed（详细含技术细节）
- **多工具适配** — 同时支持 opencode / Cursor / Claude Code / Windsurf

## 安装

```bash
git clone https://github.com/943493668/work-tracker.git
cd work-tracker
bash install.sh        # 交互式选择 lite/full
bash install.sh lite   # 仅 Git+SVN
bash install.sh full   # Git+SVN+Shell（推荐）
```

**安装范围：**
- 3 个 shell 脚本 → `~/.local/bin/`
- 2 条 cron 任务 → crontab
- 1 个 opencode skill → `~/.config/opencode/skills/weekly-report/`
- （full 模式）1 行 `~/.bashrc` → shell 钩子

## 使用

在 opencode 中：

```
生成周报           # concise 精简模式（默认）
生成详细周报       # detailed 模式，附 commit 细节
```

手动运行：

```bash
python3 ~/.config/opencode/skills/weekly-report/reporter.py              # concise
python3 ~/.config/opencode/skills/weekly-report/reporter.py detailed     # detailed
python3 ~/.config/opencode/skills/weekly-report/reporter.py 14 concise   # 最近 14 天
```

## 管理仓库

```bash
# 手动添加仓库
echo "/path/to/repo" >> ~/.local/share/work-tracker/repos.txt       # Git
echo "/path/to/repo" >> ~/.local/share/work-tracker/svn-repos.txt   # SVN
```

## 卸载

```bash
cd work-tracker
bash uninstall.sh
```

## 周报示例

### concise 模式

```
## 周报：2026-06-02 ~ 2026-06-08

### my-web-app（8 项）
1. 修复用户登录功能
2. 优化数据库查询性能
3. 新增数据导出接口

### backend-service（3 项）
1. 升级依赖版本
2. 修复 API 超时问题
3. 添加单元测试覆盖

## Statistics
- Git Commits: 12  |  SVN Commits: 5
- Shell 命令: 245 条  |  AI 会话: 8 次
```

### detailed 模式

```
### my-web-app（8 项）
1. [my-web-app][a1b2c3d] fix: 用户登录功能修复
   文件变更: 3, +45/-12
2. [my-web-app][b2c3d4e] feat: 新增数据导出接口
   文件变更: 5, 新增: 2, 修改: 2, 删除: 1

### backend-service（3 项）
1. [backend-service][r12345] chore: 升级依赖版本
   文件变更: 1, +10/-10

## Statistics
- Git Commits: 12  |  SVN Commits: 5
- Shell 命令: 245 条  |  AI 会话: 8 次
```

## 数据存储

数据全部存储在本地 `~/.local/share/work-tracker/daily/`，不上传任何服务器。

- 每日大小：~50KB
- 90 天总量：< 5MB

## License

MIT
