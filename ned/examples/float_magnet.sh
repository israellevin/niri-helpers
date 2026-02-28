#!/usr/bin/sh -e
[ "$NED_PID" ] || exec ned Workspace "$0"
MEMORY="/tmp/magnet.memory"
current_workspace="$(niri msg --json workspaces | jq -r '.[] | select(.is_focused == true) | .id')"
if [ -f "$MEMORY" ]; then
    last_focused_workspace="$(tail -n1 "$MEMORY")"
    if [ "$last_focused_workspace" != "$current_workspace" ]; then
        for window_id in $(niri msg --json windows | jq -r ".[] | \
            select(.workspace_id == $last_focused_workspace) | \
            select(.is_floating == true) | \
        .id"); do
            niri msg action move-window-to-workspace --window-id "$window_id" --focus false \
                "$(niri msg --json workspaces | jq -r '.[] | select(.is_focused == true) | .idx')"
        done
    fi
fi
echo "$current_workspace" > "$MEMORY"
