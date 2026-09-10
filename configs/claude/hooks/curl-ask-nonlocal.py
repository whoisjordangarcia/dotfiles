#!/usr/bin/env python3
"""PreToolUse hook: force a permission prompt for curl to any non-loopback host.

Loopback curl is covered by the Bash(curl *localhost:*) allow rules, so this only
needs to say "ask" for everything else. Fails closed: anything it cannot prove is
loopback gets a prompt.
"""
import json
import re
import sys

# Flags whose NEXT token is a value, not a URL.
VALUE_FLAGS = {
    "-o", "-d", "-H", "-X", "-u", "-A", "-e", "-F", "-b", "-c", "-T", "-m",
    "--output", "--data", "--data-raw", "--data-binary", "--header", "--request",
    "--user", "--user-agent", "--referer", "--form", "--cookie", "--cookie-jar",
    "--upload-file", "--max-time", "--retry", "--connect-timeout", "--resolve",
}

LOOPBACK = re.compile(r"^(localhost|127(\.\d+){3}|\[?::1\]?|0\.0\.0\.0)$", re.I)


def host_of(token):
    """Best-effort host from a curl URL argument."""
    t = re.sub(r"^[a-zA-Z][\w+.-]*://", "", token.strip("\"'"))
    t = t.split("/", 1)[0].split("?", 1)[0]
    t = t.rsplit("@", 1)[-1]  # strip userinfo
    if t.startswith("["):  # bracketed IPv6
        return t.split("]", 1)[0] + "]"
    return t.rsplit(":", 1)[0] if re.search(r":\d+$", t) else t


def is_local(cmd):
    """True only if every curl segment targets loopback and nothing else."""
    segments = re.split(r"&&|\|\||[;|\n]", cmd)
    saw_curl = False
    for seg in segments:
        tokens = seg.split()
        if not tokens or "curl" not in tokens[0]:
            continue
        saw_curl = True
        urls, skip = [], False
        for tok in tokens[1:]:
            if skip:
                skip = False
                continue
            if tok in ("--url",):
                continue  # its value is a URL; let it fall through as a bare token
            if tok.startswith("-"):
                skip = tok in VALUE_FLAGS
                continue
            urls.append(tok)
        if not urls:
            return False  # URL from a variable or stdin - can't tell, so ask
        if not all(LOOPBACK.match(host_of(u)) for u in urls):
            return False
    return saw_curl


def main():
    try:
        cmd = json.load(sys.stdin).get("tool_input", {}).get("command", "")
    except Exception:
        cmd = ""  # unparseable input -> fall through to ask
    if is_local(cmd):
        return  # silent: the loopback allow rules take it from here
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "ask",
            "permissionDecisionReason": "curl to a non-loopback host",
        }
    }))


def demo():
    assert is_local("curl localhost:3000/health")
    assert is_local("curl -sf http://localhost:8080/x")
    assert is_local("curl -o out.json http://127.0.0.1:5000/api")
    assert is_local("curl http://localhost:3000 && curl 127.0.0.1:9000")
    assert not is_local("curl https://example.com")
    assert not is_local("curl localhost:3000 && curl https://evil.com")
    assert not is_local("curl -H 'Host: localhost' https://evil.com")
    assert not is_local("curl https://evil.com/?r=http://localhost:1")
    assert not is_local('curl "$URL"')
    assert not is_local("curl http://localhost.evil.com")
    assert not is_local("ls")  # no curl at all -> hook says ask, but `if` never fires it
    print("ok")


if __name__ == "__main__":
    demo() if "--demo" in sys.argv else main()
