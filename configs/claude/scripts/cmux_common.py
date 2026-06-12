"""Shared cmux helpers for the Claude Code hook scripts.

The crux is identifying *this* session's cmux workspace. Many workspaces share a
repo cwd and `cmux identify`'s caller is null (→ focused workspace, which drifts),
so we key off GHOSTTY_SURFACE_ID — inherited by Claude's shell + hooks, stable per
terminal — mapping it once (at SessionStart, when `selected` is provably ours) to
{workspace uuid, session id} under ~/.claude/.cmux-titlemap/<gsid>.
"""
import os, json, re, subprocess, sys, glob

CLI = "/Applications/cmux.app/Contents/Resources/bin/cmux"
MAP_DIR = os.path.expanduser("~/.claude/.cmux-titlemap")


def run(args):
    return subprocess.run(args, capture_output=True, text=True)


def _socket_path():
    """Path to cmux's control socket, or '' if we can't determine one.

    Inside a cmux-launched session CMUX_SOCKET_PATH is exported; otherwise fall
    back to the per-user socket cmux creates while running. A wrong/missing path
    just means we no-op, which is the safe direction.
    """
    p = os.environ.get("CMUX_SOCKET_PATH", "").strip()
    if p:
        return p
    try:
        return os.path.expanduser(f"~/.local/state/cmux/cmux-{os.getuid()}.sock")
    except Exception:
        return ""


def alive():
    """True only when cmux is actually running — every script no-ops otherwise.

    Cheap checks first (CLI present, socket file exists) so a closed cmux — or a
    non-macOS box without the app — costs nothing: no subprocess is spawned. Only
    when a socket is present do we exec `cmux ping` to confirm it answers.
    """
    if not os.path.exists(CLI):
        return False
    sock = _socket_path()
    if not (sock and os.path.exists(sock)):
        return False
    return run([CLI, "ping"]).stdout.strip() == "PONG"


def workspaces():
    try:
        d = json.loads(run([CLI, "rpc", "workspace.list", "{}"]).stdout)
    except Exception:
        return []
    return (d.get("result") or d).get("workspaces", [])


def ghostty_surface_id():
    g = os.environ.get("GHOSTTY_SURFACE_ID", "").strip()
    if g:
        return g
    try:  # fallback: read the claude ancestor's env
        pid = os.getppid()
        for _ in range(8):
            m = re.search(r"GHOSTTY_SURFACE_ID=(\S+)", run(["ps", "eww", "-p", str(pid)]).stdout)
            if m:
                return m.group(1)
            ppid = run(["ps", "-o", "ppid=", "-p", str(pid)]).stdout.strip()
            if not ppid or ppid == "1":
                break
            pid = int(ppid)
    except Exception:
        pass
    return ""


def _map_path(gsid):
    return os.path.join(MAP_DIR, gsid) if gsid else ""


def load_map(gsid):
    p = _map_path(gsid)
    if p and os.path.isfile(p):
        try:
            return json.load(open(p))
        except Exception:
            return {}
    return {}


def save_map(gsid, workspace, session):
    if not gsid:
        return
    try:
        os.makedirs(MAP_DIR, exist_ok=True)
        json.dump({"workspace": workspace, "session": session}, open(_map_path(gsid), "w"))
    except Exception:
        pass


def read_stdin():
    """Return the hook's stdin JSON as a dict (empty on manual calls)."""
    if sys.stdin.isatty():
        return {}
    try:
        return json.load(sys.stdin) or {}
    except Exception:
        return {}


def resolve_workspace(session_hint=""):
    """Return (workspace_uuid, session_id, gsid) for this session.

    Mapping hit → stored values (robust). Miss → the *selected* workspace (correct
    at SessionStart) which is then persisted. Returns ('', ...) if undeterminable.
    """
    gsid = ghostty_surface_id()
    m = load_map(gsid)
    uuid = m.get("workspace", "")
    session_id = session_hint or m.get("session", "")
    if not uuid:
        sel = next((w for w in workspaces() if w.get("selected")), None)
        if not sel:
            return "", session_id, gsid
        uuid = sel.get("id", "")
        if uuid:
            save_map(gsid, uuid, session_id)
    return uuid, session_id, gsid


def is_selected(uuid):
    return any(w.get("selected") and w.get("id") == uuid for w in workspaces())
