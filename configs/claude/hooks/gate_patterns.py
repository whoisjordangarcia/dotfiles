"""Shared sensitive-command patterns for the touchid-gate hooks.

Canonical source imported by both the Claude Code and Codex PreToolUse hooks
(configs/claude/hooks/touchid-gate.py and configs/codex/hooks/touchid-gate.py)
so the tripwire list can't silently drift between the two.

(regex, human label) — keep this list short and high-signal to avoid prompt
fatigue. Tune freely; it lives in dotfiles.
"""

PATTERNS = [
    (r"\bsudo\b", "sudo (root)"),
    (r"\brm\s+(-[A-Za-z]*r[A-Za-z]*f|-[A-Za-z]*f[A-Za-z]*r)\S*\s+(\"?(/|~|\$HOME))", "recursive delete of home/root path"),
    (r"git\s+push\b[^|;&]*(\s--force\b|\s-f\b|\s--force-with-lease\b)", "git force push"),
    (r"prd-account|--profile[= ]\S*prd", "production AWS profile"),
    (r"\bop\s+(read|item\s+get|inject|document\s+get)\b", "1Password secret access"),
    (r"security\s+\S*-password\b", "macOS keychain access"),
    (r"(curl|wget)\b[^|;&]*\|\s*(ba|z)?sh\b", "pipe remote script into shell"),
    (r"gh\s+(repo|release)\s+delete\b", "GitHub destructive delete"),
    (r"\.zshrc\.sec\b(?!\.)|\.zshrc-sec\b", "shell secrets file access"),
]
