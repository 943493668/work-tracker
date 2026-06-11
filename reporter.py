#!/usr/bin/env python3
import json
import os
import shutil
import sqlite3
import sys
import tempfile
from datetime import datetime, timedelta
from pathlib import Path

WORK_TRACKER_DIR = Path.home() / ".local" / "share" / "work-tracker"
DAILY_DIR = WORK_TRACKER_DIR / "daily"
CONFIG_FILE = WORK_TRACKER_DIR / "config.json"


def _find_opencode_db() -> Path:
    wsl_native = Path.home() / ".local" / "share" / "opencode" / "opencode.db"
    win_user = Path("/mnt/c/Users")
    if win_user.exists():
        win_name = ""
        for d in sorted(win_user.iterdir(), key=lambda p: p.stat().st_mtime, reverse=True):
            if d.is_dir() and d.name not in ("Public", "Default", "Default User", "All Users"):
                win_name = d.name
                break
        if win_name:
            win_db = win_user / win_name / ".local" / "share" / "opencode" / "opencode.db"
            if win_db.exists():
                return win_db
    return wsl_native


OPENCODE_DB = _find_opencode_db()


def _detect_win_username() -> str:
    win_users = Path("/mnt/c/Users")
    if not win_users.exists():
        return ""
    skip = {"Public", "Default", "Default User", "All Users"}
    for d in sorted(win_users.iterdir(), key=lambda p: p.stat().st_mtime, reverse=True):
        if d.is_dir() and d.name not in skip:
            return d.name
    return ""


def log_warning(msg):
    print(f"[warn] {msg}", file=sys.stderr)

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
            except json.JSONDecodeError as e:
                log_warning(f"invalid JSON in {log_file}: {e}")
    return activities

def _open_opencode_db():
    """Open readonly; fallback to a temp copy if lock contention."""
    try:
        conn = sqlite3.connect(
            f"file:{OPENCODE_DB}?mode=ro",
            uri=True,
            timeout=3,
        )
        conn.execute("PRAGMA busy_timeout = 3000")
        conn.execute("SELECT count(*) FROM session")
        return conn
    except Exception as e:
        log_warning(f"readonly open failed ({e}), falling back to temp copy")
        tmp = tempfile.mktemp(suffix=".db", prefix="opencode_report_")
        try:
            shutil.copy2(str(OPENCODE_DB), tmp)
            conn = sqlite3.connect(tmp, timeout=5)
            conn.execute("PRAGMA busy_timeout = 5000")
            return conn
        except Exception as e2:
            log_warning(f"temp copy also failed: {e2}")
            return None

def _load_known_repos():
    repos = {}
    for fname in ("repos.txt", "svn-repos.txt"):
        repo_file = WORK_TRACKER_DIR / fname
        if repo_file.exists():
            for line in repo_file.read_text().strip().splitlines():
                line = line.strip()
                if line:
                    repos[Path(line).name] = line
    return repos


def _infer_project_from_messages(user_msgs, known_repos):
    meaningful = [m for m in user_msgs if not m.lstrip().startswith("##")]
    all_text = " ".join(meaningful)
    home_variants = [str(Path.home()), f"/home/{Path.home().name}"]
    for repo_name, repo_path in known_repos.items():
        if repo_name in all_text or repo_path in all_text:
            return repo_name
        path_variants = [
            repo_path.replace("\\", "/"),
        ]
        for h in home_variants:
            path_variants.append(repo_path.replace(f"{h}/", ""))
        for v in path_variants:
            if v in all_text:
                return repo_name
    return None


def read_opencode_sessions(start, end):
    sessions = []
    if not OPENCODE_DB.exists():
        return sessions
    conn = _open_opencode_db()
    if conn is None:
        return sessions
    known_repos = _load_known_repos()
    try:
        cur = conn.cursor()
        start_ms = int(start.timestamp() * 1000)
        cur.execute("""
            SELECT id, title, time_created, model, directory, parent_id
            FROM session WHERE time_created >= ? ORDER BY time_created DESC
        """, (start_ms,))
        for row in cur.fetchall():
            sid, title, created, model_str, directory, parent_id = row
            is_subagent = parent_id is not None
            model = ""
            try:
                m = json.loads(model_str) if model_str else {}
                model = m.get("modelID", "")
            except Exception:
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
                            user_msgs.append(p.get("text", "")[:200])
                    except Exception:
                        pass
            dt = datetime.fromtimestamp(created / 1000)
            home_path = str(Path.home())
            home_name = Path(home_path).name
            normalized_dir = directory or ""
            if normalized_dir.startswith("//wsl.localhost/"):
                parts = normalized_dir.split("/")
                if len(parts) >= 5:
                    normalized_dir = "/" + "/".join(parts[4:])
            win_user = _detect_win_username()
            user_home_dirs = {home_path, f"/home/{home_name}"}
            if win_user:
                user_home_dirs.add(f"/mnt/c/Users/{win_user}")
            if not normalized_dir or normalized_dir in user_home_dirs:
                inferred = _infer_project_from_messages(user_msgs, known_repos)
                project = inferred if inferred else "opencode 杂项"
            else:
                dir_name = Path(normalized_dir).name
                if dir_name in ("Users", home_name, win_user):
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
                "user_messages": user_msgs[:8],
                "is_subagent": is_subagent
            })
    except Exception as e:
        log_warning(f"read_opencode_sessions error: {e}")
    finally:
        try:
            db_path = conn.execute("PRAGMA database_list").fetchall()
            conn.close()
            for _, _, path in db_path:
                if path and path.startswith(tempfile.gettempdir()):
                    try:
                        os.unlink(path)
                    except OSError:
                        pass
        except Exception:
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

    stats = {"git": 0, "svn": 0, "shell": 0, "opencode": 0, "opencode_sub": 0}
    for a in all_activities:
        t = a.get("type", "")
        if "git" in t: stats["git"] += 1
        elif "svn" in t: stats["svn"] += 1
        elif t == "shell_command": stats["shell"] += 1
        elif t == "opencode_session":
            if a.get("is_subagent"):
                stats["opencode_sub"] += 1
            else:
                stats["opencode"] += 1

    for project, items in sorted(groups.items()):
        if project == "other":
            continue
        seen = set()
        display_items = []
        for item in items:
            t = item.get("type", "")
            if t in ("git_commit", "svn_commit"):
                msg = item.get("message", "").strip()
                if not msg or msg in seen or len(msg) < 3:
                    continue
                seen.add(msg)
                display_items.append(("commit", item))
            elif t == "opencode_session":
                if item.get("is_subagent") and mode == "concise":
                    continue
                title = item.get("title", "") or ""
                if title.lower() == "greeting" or title in seen:
                    continue
                seen.add(title)
                if title.startswith("New session -"):
                    fallback = ""
                    for um in item.get("user_messages", []):
                        s = um.replace('\n', ' ').strip()
                        if s and len(s) > 5 and not s.startswith("##"):
                            fallback = s[:50]
                            break
                    if not fallback and mode == "concise":
                        continue
                    item = dict(item)
                    item["title"] = fallback or title
                display_items.append(("session", item))
        if not display_items:
            continue
        print(f"### {project} ({len(display_items)} 项)\n")
        idx = 1
        for kind, item in display_items:
            if kind == "commit":
                msg = item.get("message", "").strip()
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
            else:
                title = item.get("title", "") or "untitled"
                if mode == "concise":
                    print(f"{idx}. {title[:50]}")
                else:
                    prefix = "  [sub]" if item.get("is_subagent") else ""
                    print(f"{idx}. {prefix}{title}")
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
    total_ai = stats["opencode"] + stats["opencode_sub"]
    if total_ai:
        if stats["opencode_sub"]:
            print(f"- AI 会话: {total_ai} 次 (含 {stats['opencode_sub']} 次子任务)")
        else:
            print(f"- AI 会话: {total_ai} 次")

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
