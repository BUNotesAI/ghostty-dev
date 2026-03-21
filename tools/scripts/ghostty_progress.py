#!/usr/bin/env python3
"""Ghostty progress log CLI.

Usage:
    ghostty_progress.py append <message>
    ghostty_progress.py clear
    ghostty_progress.py list
    ghostty_progress.py sessions

Session name is derived automatically from $GHOSTTY_TAB_ID.
"""
import sys, os, re, time
from pathlib import Path

DIR = Path("/tmp/ghostty-progress")
SESSION_RE = re.compile(r'^[A-Za-z0-9_-]+$')


def get_session() -> str:
    """Derive session name from GHOSTTY_TAB_ID (first 2 chars, prefixed)."""
    tab_id = os.environ.get("GHOSTTY_TAB_ID", "")
    if not tab_id:
        print("Error: GHOSTTY_TAB_ID not set (not running inside Ghostty Dev?)", file=sys.stderr)
        sys.exit(1)
    prefix = tab_id[:2]
    return f"GD-{prefix}"


def validate_session(session: str) -> str:
    if not SESSION_RE.match(session):
        print(f"Error: invalid session name '{session}' (only A-Z, a-z, 0-9, _, - allowed)", file=sys.stderr)
        sys.exit(1)
    return session


def get_file(session: str) -> Path:
    DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
    return DIR / f"{session}.log"


def append(session: str, message: str):
    ts = time.strftime("%H:%M")
    line = f"{ts} | {message}\n"
    try:
        with open(get_file(session), "a") as f:
            f.write(line)
    except OSError as e:
        print(f"Error: could not write to log: {e}", file=sys.stderr)
        sys.exit(1)


def clear(session: str):
    f = get_file(session)
    if f.exists():
        f.write_text("")


def list_entries(session: str):
    f = get_file(session)
    if f.exists():
        print(f.read_text(), end="")


def sessions():
    if DIR.exists():
        for f in sorted(DIR.glob("*.log")):
            print(f.stem)


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args or args[0] == "help":
        print(__doc__)
        sys.exit(0)
    cmd = args[0]
    if cmd == "append" and len(args) >= 2:
        session = validate_session(get_session())
        append(session, " ".join(args[1:]))
    elif cmd == "clear":
        session = validate_session(get_session())
        clear(session)
    elif cmd == "list":
        session = validate_session(get_session())
        list_entries(session)
    elif cmd == "sessions":
        sessions()
    else:
        print(f"Error: invalid command or missing arguments.\n{__doc__}", file=sys.stderr)
        sys.exit(1)
