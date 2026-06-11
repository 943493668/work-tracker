# Work Tracker

一个面向开发者的本地工作记录与周报生成工具。

Work Tracker 会持续收集你在本机上的开发活动，包括 Git / SVN 提交、Shell 命令，以及 AI 编程工具中的对话记录，再按项目归类整理成可直接提交的周报。

## 为什么用它

很多周报并不是不会写，而是信息散在 Git、终端、聊天记录和不同项目目录里，回头整理很耗时间。Work Tracker 的目标就是把这件事自动化。

**它解决什么问题：** 把分散的开发痕迹统一沉淀到本地日志里，生成按项目分组的工作摘要，减少手工翻记录和补记忆。

**它怎么工作：** 定时采集仓库提交，记录终端命令，读取 AI 会话数据，再按时间范围输出 concise 或 detailed 两种周报。

**它适合什么场景：** 个人周报、项目复盘、阶段工作回顾，以及需要回看最近几天都做了什么的时候。

**它的特点：** 全本地存储、零常驻服务、安装简单、适合 WSL + Windows 混合开发环境，也能和 opencode / Codex 等工具一起使用。

## 功能

- **Git 提交追踪** — 定时扫描本地 Git 仓库提交记录
- **SVN 提交追踪** — 定时扫描本地 SVN 仓库提交记录
- **Shell 命令记录** — 通过 shell hook 记录终端命令（full 模式）
- **AI 会话汇总** — 支持读取 OpenCode 和 Codex 本地会话数据
- **两种周报模式** — concise 适合上交，detailed 适合复盘
- **按项目聚合输出** — 把提交、命令和 AI 会话统一归类到项目维度

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
python3 reporter.py                                     # 在仓库目录执行
python3 reporter.py detailed                            # detailed
python3 reporter.py 14 concise                          # 最近 14 天
python3 ~/.config/opencode/skills/weekly-report/reporter.py concise
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
- Shell 命令: 245 条
- Codex 会话: 4 次  |  OpenCode 会话: 8 次
- AI 会话总计: 12 次
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
- Shell 命令: 245 条
- Codex 会话: 4 次  |  OpenCode 会话: 8 次
- AI 会话总计: 12 次
```

## 数据存储

工作日志存储在本地 `~/.local/share/work-tracker/daily/`。AI 会话数据从本地数据库读取，不上传到任何服务器。

- 每日大小：~50KB
- 90 天总量：< 5MB

## License

MIT
