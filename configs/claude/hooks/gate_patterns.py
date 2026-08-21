"""Shared sensitive-command patterns for the touchid-gate hooks.

Canonical source imported by both the Claude Code and Codex PreToolUse hooks
(configs/claude/hooks/touchid-gate.py and configs/codex/hooks/touchid-gate.py)
so the tripwire list can't silently drift between the two.

Each entry is (regex, human label, mode), where mode is how the dialog may be
approved:

  "bio"      a Touch ID press or YubiKey tap — no Approve button
  "confirm"  the same dialog, but clicking Approve is enough
  "ask"      no dialog at all — defer to the agent's own permission prompt

Keep the list short and high-signal to avoid prompt fatigue. Tune freely; it
lives in dotfiles.
"""

import os

# Always active, in every directory. Losing these silently is the failure mode
# worth avoiding, so nothing here is project-scoped.
GLOBAL_PATTERNS = [
    # No sudo entry on purpose: /etc/pam.d/sudo_local enables pam_tid, so sudo
    # raises its own Touch ID prompt. Gating it here just asked for the same
    # fingerprint twice. Residual gap: sudo's timestamp cache (~5 min) means a
    # sudo shortly after your own runs unchallenged.
    (r"\brm\s+(-[A-Za-z]*r[A-Za-z]*f|-[A-Za-z]*f[A-Za-z]*r)\S*\s+(\"?(/|~|\$HOME))", "recursive delete of home/root path", "bio"),
    # confirm, not bio: the value here is reading the DROPPED-commits preview the
    # dialog renders, not proving who read it.
    (r"git\s+push\b[^|;&]*(\s--force\b|\s-f\b|\s--force-with-lease\b)", "git force push", "confirm"),
    (r"prd-account|--profile[= ]\S*prd", "production AWS profile", "confirm"),
    (r"\bop\s+(read|item\s+get|inject|document\s+get)\b", "1Password secret access", "bio"),
    (r"security\s+\S*-password\b", "macOS keychain access", "bio"),
    (r"(curl|wget)\b[^|;&]*\|\s*(ba|z)?sh\b", "pipe remote script into shell", "bio"),
    # Must stay below the pipe-to-shell entry — first match wins, so `curl … | sh`
    # keeps its biometric gate and only the tamer curls fall through to a prompt.
    # This replaces a `Bash(curl *)` rule in permissions.ask, which double-prompted:
    # ask rules are re-evaluated after the hook, so they re-asked what Touch ID
    # had already approved.
    # Anchored at a command position so `brew install curl` / `man curl` stay quiet;
    # the rule it replaces was prefix-matched, so plain `\bcurl\b` would be noisier
    # than what it stands in for.
    (r"(^|[|;&]\s*)curl\b", "curl (network call)", "ask"),
    (r"gh\s+(repo|release)\s+delete\b", "GitHub destructive delete", "bio"),
    (r"\.zshrc\.sec\b(?!\.)|\.zshrc-sec\b", "shell secrets file access", "bio"),
]

# Opt-in extras, switched on per project in ~/.config/bioprompt/projects.conf.
SCOPED_PATTERNS = {
    "git-write": [
        (r"\bgit\s+commit\b", "git commit", "bio"),
        (r"\bgit\s+push\b", "git push", "ask"),
    ],
}

PROJECTS_CONF = os.path.expanduser("~/.config/bioprompt/projects.conf")


def scopes_for(cwd, conf_path=PROJECTS_CONF):
    """Scope names enabled for `cwd`, from `<path prefix> <scope>...` lines.

    A missing or unreadable config means "no extra scopes" — the global
    patterns still apply, so a broken config can't disable the tripwire.
    """
    try:
        with open(conf_path, encoding="utf-8") as fh:
            lines = fh.readlines()
    except OSError:
        return []

    try:
        here = os.path.realpath(cwd)
    except (OSError, ValueError):
        return []

    scopes = []
    for line in lines:
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        prefix, *names = line.split()
        if not names:
            continue
        prefix = os.path.realpath(os.path.expanduser(prefix))
        # Compare on a path boundary so ~/dev/dot doesn't match ~/dev/dotfiles.
        if here == prefix or here.startswith(prefix + os.sep):
            for name in names:
                scopes.extend(n for n in name.split(",") if n and n not in scopes)
    return scopes


def patterns_for(cwd, conf_path=PROJECTS_CONF):
    """Global patterns plus whatever this project opted into.

    Globals come first because first match wins: in a `git-write` project a
    `git push --force` must still match "git force push" (which renders the
    commit preview) rather than the broader scoped "git push".
    """
    scoped = []
    for name in scopes_for(cwd, conf_path):
        scoped.extend(SCOPED_PATTERNS.get(name, ()))
    return GLOBAL_PATTERNS + scoped
