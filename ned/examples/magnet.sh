#!/usr/bin/sh -e
[ "$NED_PID" ] || exec ned Workspace "$0 $*"
MEMORY="/tmp/magnet.memory"

get() {
    niri msg --json "$1" | jq -r "$2"
}

current_workspace="$(get workspaces '.[] | select(.is_focused == true) | .id')"

if [ -f "$MEMORY" ]; then
    previous_workspace="$(tail -n1 "$MEMORY")"
    rm "$MEMORY" 2>/dev/null
    if [ "$previous_workspace" != "$current_workspace" ]; then
        previous_workspace_idx="$(get workspaces '.[] | select(.id == '"$previous_workspace"') | .idx')"
        niriu.sh flock --workspace "$previous_workspace_idx" "$@"
    fi
fi

echo "$current_workspace" > "$MEMORY"
