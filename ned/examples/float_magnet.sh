#!/usr/bin/sh -e
[ "$NED_PID" ] || exec ned Workspace "$0"
MEMORY="/tmp/magnet.memory"
current_workspace="$(niri msg --json workspaces | jq -r '.[] | select(.is_focused == true) | .id')"
if [ -f "$MEMORY" ]; then
    previous_workspace="$(tail -n1 "$MEMORY")"
    rm "$MEMORY" 2>/dev/null
    if [ "$previous_workspace" ] && [ "$previous_workspace" != "$current_workspace" ]; then
        for window_id in $(niri msg --json windows | jq -r ".[] | \
            select(.workspace_id == $previous_workspace) | \
            select(.is_floating == true) | \
        .id"); do
            niri msg action move-window-to-workspace --window-id "$window_id" --focus false \
                "$(niri msg --json workspaces | jq -r '.[] | select(.is_focused == true) | .idx')"
        done
    fi
fi
echo "$current_workspace" > "$MEMORY"
