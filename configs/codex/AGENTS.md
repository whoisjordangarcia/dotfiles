# Personal Codex Guidelines

## Sensitive files

Never read, print, copy, patch, stage, or commit secrets or credential files. Treat the following as denied unless the user explicitly identifies a specific file and asks to use it:

- `.env`, `.env.*`, and `secrets/**`
- `*.htpasswd`, `*.jks`, `*.key`, `*.keystore`, `*.netrc`, `*.npmrc`
- `*.p12`, `*.pem`, `*.pfx`, `*.pgpass`, `*.pypirc`, and names containing `credentials`
- `~/.aws/**`, `~/.ssh/**`, `.zshrc.sec`, and `.zshrc-sec`

Do not expose secret values in command output. Prefer commands that test existence or metadata without reading contents.

## Sensitive operations

Ask before `git push` or direct `curl` use. Commands involving production AWS profiles, privilege escalation, force-pushes, destructive deletion, 1Password secret reads, macOS Keychain password reads, or piping downloads into a shell require explicit approval and may also be protected by the local biometric hook.
