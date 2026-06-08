# Weekly Report 生成规则

## 触发条件
当用户说以下内容时触发：
- "生成周报" / "generate weekly report"
- "总结本周/本月工作"
- "查看最近 X 天的工作内容"
- "weekly report"

## 执行步骤

1. 运行周报生成脚本：
   - concise 模式（精简，5-15字/条）：`python3 ~/.local/share/work-tracker/reporter.py concise`
   - detailed 模式（详细）：`python3 ~/.local/share/work-tracker/reporter.py detailed`
   - 指定天数：`python3 ~/.local/share/work-tracker/reporter.py 14 concise`

2. 基于脚本输出的原始数据，按以下格式精简总结：
   - 按项目分组
   - 每条文摘 5-15 个字（concise 时）
   - 末尾附上统计信息（Git/SVN 提交数、AI 会话数）

## 输出示例（concise）

```
## 周报：2026-06-01 ~ 2026-06-08

### hyf_lobehub（8 项）
1. 修复智能体展示名称问题
2. 解决退出登录功能无效
3. 修复注册页面请求卡死

### 统计
- SVN Commits: 8
- AI 会话: 5 次
```

## 数据来源说明
- Git 提交：`~/.local/share/work-tracker/repos.txt` 中注册的仓库
- SVN 提交：`~/.local/share/work-tracker/svn-repos.txt` 中注册的仓库
- Shell 命令：通过 ~/.bashrc 钩子自动记录
- opencode 对话：实时读取 `~/.local/share/opencode/opencode.db`
