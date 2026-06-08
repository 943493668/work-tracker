#!/usr/bin/env python3
import json
import sqlite3
import sys
from datetime import datetime, timedelta
from pathlib import Path

WORK_TRACKER_DIR = Path.home() / ".local" / "share" / "work-tracker"
DAILY_DIR = WORK_TRACKER_DIR / "daily"
CONFIG_FILE = WORK_TRACKER_DIR / "config.json"
OPENCODE_DB = Path.home() / ".local" / "share" / "opencode" / "opencode.db"

def load_config():
    if CONFIG_FILE.exists():
        return json.loads(CONFIG_FILE.read_text())
    return {"report_mode": "concise"}

def get_date_range(days=7):
    end = datetime.now()
    start = end - timedelta(days=days)
    return start, end

def read_daily_logs(start, end):
    activities = []
    for i in range((end - start).days + 1):
        day = start + timedelta(days=i)
        date_str = day.strftime("%Y-%m-%d")
        log_file = DAILY_DIR / f"{date_str}.json"
        if log_file.exists():
            try:
                data = json.loads(log_file.read_text())
                activities.extend(data.get("activities", []))
            except json.JSONDecodeError:
                pass
    return activities

def read_opencode_sessions(start, end):
    sessions = []
    if not OPENCODE_DB.exists():
        return sessions
    try:
        conn = sqlite3.connect(f"file:{OPENCODE_DB}?mode=ro", uri=True)
        cur = conn.cursor()
        start_ms = int(start.timestamp() * 1000)
        cur.execute("""
            SELECT id, title, time_created, model, directory
            FROM session WHERE time_created >= ? ORDER BY time_created DESC
        """, (start_ms,))
        for sid, title, created, model_str, directory in cur.fetchall():
            model = ""
            try:
                m = json.loads(model_str) if model_str else {}
                model = m.get("modelID", "")
            except:
                pass
            cur.execute("""
                SELECT id, time_created FROM message
                WHERE session_id = ? AND data LIKE '%"role":"user"%'
                ORDER BY time_created ASC
            """, (sid,))
            user_msgs = []
            for mid, mtime, in cur.fetchall():
                cur.execute("SELECT data FROM part WHERE message_id = ?", (mid,))
                for (part_data,) in cur.fetchall():
                    try:
                        p = json.loads(part_data)
                        if p.get("type") == "text":
                            user_msgs.append(p.get("text", "")[:120])
                    except:
                        pass
            dt = datetime.fromtimestamp(created / 1000)
            home_path = str(Path.home())
            home_name = Path(home_path).name
            # 判断目录是否是用户主目录（WSL 或 Windows）
            if not directory or directory in (home_path, f"/mnt/c/Users/{home_name}", "/mnt/c/Users/Lenovo"):
                project = "opencode 杂项"
            else:
                dir_name = Path(directory).name
                # Windows Users 文件夹也算是主目录
                if dir_name in ("Users", home_name, "Lenovo"):
                    project = "opencode 杂项"
                else:
                    project = dir_name
            sessions.append({
                "type": "opencode_session",
                "time": dt.strftime("%Y-%m-%dT%H:%M:%S"),
                "session_id": sid,
                "title": title or "untitled",
                "model": model,
                "directory": directory or "",
                "project": project,
                "user_messages": user_msgs[:8]
            })
        conn.close()
    except:
        pass
    return sessions

def group_by_project(activities):
    groups = {}
    for a in activities:
        t = a.get("type", "")
        if t == "opencode_session":
            key = a.get("project", "opencode")
        elif t == "shell_command":
            cwd = a.get("cwd", "")
            key = Path(cwd).name if cwd else "other"
        else:
            key = a.get("repo", "other") or "other"
        groups.setdefault(key, []).append(a)
    return groups

def print_report(start, end, mode="concise"):
    daily = read_daily_logs(start, end)
    opencode = read_opencode_sessions(start, end)
    all_activities = daily + opencode
    groups = group_by_project(all_activities)

    start_str = start.strftime("%Y-%m-%d")
    end_str = end.strftime("%Y-%m-%d")

    print(f"## 周报：{start_str} ~ {end_str}\n")

    stats = {"git": 0, "svn": 0, "shell": 0, "opencode": 0}
    for a in all_activities:
        t = a.get("type", "")
        if "git" in t: stats["git"] += 1
        elif "svn" in t: stats["svn"] += 1
        elif t == "shell_command": stats["shell"] += 1
        elif t == "opencode_session": stats["opencode"] += 1

    for project, items in sorted(groups.items()):
        if project == "other":
            continue
        printable = [i for i in items if i.get("type") in ("git_commit", "svn_commit", "opencode_session")]
        if not printable:
            continue
        print(f"### {project} ({len(printable)} 项)\n")
        seen = set()
        idx = 1
        for item in items:
            t = item.get("type", "")
            if t in ("git_commit", "svn_commit"):
                msg = item.get("message", "").strip()
                if not msg or msg in seen or len(msg) < 3:
                    continue
                seen.add(msg)
                if mode == "concise":
                    print(f"{idx}. {msg[:40]}")
                else:
                    repo = item.get("repo", "")
                    extra = f" [{item.get('hash', item.get('revision', ''))}]" if "revision" not in item else f" [r{item.get('revision')}]"
                    print(f"{idx}. [{repo}]{extra} {msg}")
                    fc = item.get("files_changed", 0)
                    ins = item.get("insertions", 0)
                    dl = item.get("deletions", 0)
                    if ins or dl:
                        print(f"   文件变更: {fc}, +{ins}/-{dl}")
                idx += 1
            elif t == "opencode_session":
                title = item.get("title", "")
                if not title or title.startswith("New session -") or title in seen or title.lower() == "greeting":
                    continue
                seen.add(title)
                if mode == "concise":
                    print(f"{idx}. {title[:50]}")
                else:
                    print(f"{idx}. {title}")
                    for um in item.get("user_messages", [])[:3]:
                        preview = um.replace('\n', ' ')[:80]
                        if preview.strip():
                            print(f"   > {preview}")
                idx += 1
        print()

    print("## Statistics\n")
    if stats["git"]:
        print(f"- Git Commits: {stats['git']}")
    if stats["svn"]:
        print(f"- SVN Commits: {stats['svn']}")
    if stats["shell"]:
        print(f"- Shell 命令: {stats['shell']} 条")
    if stats["opencode"]:
        print(f"- AI 会话: {stats['opencode']} 次")

if __name__ == "__main__":
    config = load_config()
    mode = config.get("report_mode", "concise")
    days = 7
    if len(sys.argv) > 1:
        if sys.argv[1] in ("concise", "detailed"):
            mode = sys.argv[1]
        elif sys.argv[1].isdigit():
            days = int(sys.argv[1])
    if len(sys.argv) > 2 and sys.argv[2] in ("concise", "detailed"):
        mode = sys.argv[2]
    start, end = get_date_range(days)
    print_report(start, end, mode)
