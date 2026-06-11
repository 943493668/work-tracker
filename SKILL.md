---
name: weekly-report
description: 汇总本地开发活动与 AI 会话记录，按项目生成 concise 或 detailed 周报，适合做周报上交和工作复盘。
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: generate-on-demand
---

## What I do

1. 读取 `~/.local/share/work-tracker/daily/` 下指定范围内的 JSON 日志
2. 同时查询 OpenCode / Codex 的本地会话数据
3. 将所有活动按项目和类型分类
4. 使用 AI 智能总结，生成结构化周报

## How to use

运行以下命令获取原始数据，然后基于输出进行总结：

```bash
# concise 模式（默认，每条 5-15 字摘要）
python3 reporter.py concise

# detailed 模式（完整技术细节）
python3 reporter.py detailed

# 指定天数 + 模式
python3 reporter.py 14 detailed
```

## Report modes

### concise（默认）

每条控制在 5-15 字，适合作为周报上交：

```
## 周报：2026-06-02 ~ 2026-06-08

### hyf_lobehub（8 项）
1. 修复智能体展示名称问题
2. 解决退出登录功能无效
3. 修复注册页面请求卡死

### 统计
- Git Commits: 12  |  SVN Commits: 5
- Shell 命令: 245 条
- Codex 会话: 4 次  |  OpenCode 会话: 8 次
- AI 会话总计: 12 次
```

### detailed

包含 commit hash、文件变更统计、对话上下文，适合团队复盘：

```
### hyf_lobehub（8 项）
1. [hyf_lobehub][a1b2c3d] fix: 智能体展示名称显示为ID
   文件变更: 3, +45/-12
2. [hyf_lobehub] 修复注册页面请求卡死
   > 帮我查下为什么注册页面请求卡死了...
```

## When to use me

当用户说：
- "生成周报" / "weekly report"
- "这周做了什么" / "总结本周/本月工作"
- "查看最近 X 天的工作内容"
- 用户要求详细报告时使用 detailed 模式，否则默认 concise
