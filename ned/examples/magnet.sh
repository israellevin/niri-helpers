#!/usr/bin/sh -e
[ "$NED_PID" ] || exec ned Workspace "$0 $*"
MEMORY="/tmp/magnet.memory"
current_workspace="$(niri msg --json workspaces | jq -r '.[] | select(.is_focused == true) | .id')"
if [ -f "$MEMORY" ]; then
    previous_workspace="$(tail -n1 "$MEMORY")" || return 0
    rm "$MEMORY" 2>/dev/null
    if [ "$previous_workspace" ] && [ "$previous_workspace" != "$current_workspace" ]; then
        previous_workspace_idx="$(niri msg --json workspaces | \
            jq '.[] | select(.id == '"$previous_workspace"') | .idx')"
        niriu.sh flock --workspace "$previous_workspace_idx" "$@"
    fi
fi
echo "$current_workspace" > "$MEMORY"
