#!/bin/bash
# Pane border title with gradient effect by command type
# Args: $1=pane_active $2=pane_current_command $3=pane_current_path_basename

active="$1"
cmd="$2"
path="$3"

# Claude Code sets pane_current_command to its version (e.g. "2.1.32")
is_claude() { [[ "$1" == [0-9]* || "$1" == *claude* ]]; }

if [[ "$active" != "1" ]]; then
    label="$cmd"
    is_claude "$cmd" && label="claude"
    [[ "$cmd" == "zsh" ]] && label="$path"
    echo "#[align=centre,fg=colour238] $label "
    exit 0
fi

# Active pane - gradient by command
if is_claude "$cmd"; then
    echo "#[align=left]#[fg=colour17]━━#[fg=colour24]━━#[fg=colour31]━━#[fg=colour45,bold] 󰚩 claude #[nobold,fg=colour31]━━#[fg=colour24]━━#[fg=colour17]━━"
elif [[ "$cmd" == *nvim* ]]; then
    echo "#[align=left]#[fg=colour22]━━#[fg=colour28]━━#[fg=colour34]━━#[fg=colour82,bold]  nvim #[nobold,fg=colour34]━━#[fg=colour28]━━#[fg=colour22]━━"
elif [[ "$cmd" == *nx* ]]; then
    echo "#[align=left]#[fg=colour94]━━#[fg=colour130]━━#[fg=colour166]━━#[fg=colour208,bold] 󰬡 nx #[nobold,fg=colour166]━━#[fg=colour130]━━#[fg=colour94]━━"
else
    label="$cmd"
    [[ "$cmd" == "zsh" ]] && label="$path"
    echo "#[align=left]#[fg=colour236]━━#[fg=colour240]━━#[fg=colour245,bold] $label #[nobold,fg=colour240]━━#[fg=colour236]━━"
fi
