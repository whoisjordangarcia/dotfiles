# unused

Parked, not deleted: configs and modules that nothing in the repo installs or reads any more. They keep their
original path under this folder (`unused/configs/i3` was `configs/i3`), so restoring one is a `git mv` back plus,
for a module, a line in the right `script/<system>_components.sh`.

| Path | What it was | Why it is here |
|---|---|---|
| `configs/i3/` | i3 window manager config (Fedora desktop) | no module links it; the Fedora profile is unmaintained |
| `configs/sway/` | Sway compositor config | no module links it |
| `configs/lazydocker/` | lazydocker `config.yml` | no module links it |
| `script/apps/server-lite/` | minimal apt package set | in no profile's component list; `apps/server` replaced it |

Rule for adding to this folder: a config goes here when no `script/**/setup.sh`, no other config and no doc refers
to it. Anything with a live consumer stays where it is, even without a module of its own (`configs/ai-stats` is
read by the sketchybar widget and the statusline; `configs/ts-rex` holds launchd plists that are loaded by hand).
