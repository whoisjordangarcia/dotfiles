#!/bin/bash
# zmx_bridge.sh — expose zmx sessions to tmux-only clients.
#
# tmux can't adopt a foreign PTY, so we wrap: each zmx session `foo` gets a
# detached tmux session `zmx-foo` whose single pane runs `zmx attach foo`.
# From then on `tmux attach/send-keys/capture-pane -t zmx-foo` drives the live
# zmx session. Killing the wrapper only detaches; the zmx session survives.
#
# Idempotent — safe to re-run. Called by the `zmt` shell function and by the
# com.jordangarcia.zmx-tmux-bridge launchd agent (WatchPaths on $ZMX_DIR).
#
#   zmx_bridge.sh          bridge every zmx session
#   zmx_bridge.sh -a       ...including Supacode's internal supa-<uuid> ones
#   zmx_bridge.sh foo bar  bridge only these
#
# Scrollback lives in zmx, not tmux: use `zmx history <name>`, not capture-pane.

PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin
command -v zmx >/dev/null || exit 0

all=""
[[ "$1" == "-a" ]] && { all=1; shift; }

sessions=$*
[[ -n "$sessions" ]] || sessions=$(zmx list --short 2>/dev/null)

for n in $sessions; do
  # Supacode spawns one zmx session per surface; bridging them all buries the
  # real sessions in tmux ls. Same default as the `zma` picker.
  [[ -z "$all" && "$n" == supa-* ]] && continue
  # "=" forces an exact match — without it, an existing zmx-foobar would make
  # tmux report zmx-foo as present and silently skip the bridge.
  tmux has-session -t "=zmx-$n" 2>/dev/null && continue
  # -x/-y: a detached session defaults to 80x24, and zmx repaints garbled over
  # the stale frame when a real client later attaches at a bigger size.
  tmux new-session -d -s "zmx-$n" -x 200 -y 50 "zmx attach '$n'" && echo "zmx-$n"
done
