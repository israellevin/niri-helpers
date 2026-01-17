#!/usr/bin/sh
usage() {
    cat <<EOF
Usage: niriwindo.sh COMMAND [OPTIONS]... ARGUMENTS
Manage Niri windows.
Commands:
  ids [OPTIONS]...              Output IDs of windows matching criteria.
  tile [OPTIONS]...             Grab all matching windows and tile them in an optimal grid layout.
  windo [OPTIONS]... ACTION     Perform ACTION (a single string argument) on windows matching criteria.
Options:
  --filter JQ_FILTER       Apply a custom jq filter to select windows.
  --appid APP_ID           Select windows by application ID.
  --title TITLE            Select windows by title (substring match).
  --workspace WORKSPACE_IDX Select windows by workspace index or 'focused' for the focused workspace.
EOF
    exit "$1"
}

get_focused_workspace_property() {
    niri msg --json workspaces | jq -r ".[] | select(.is_focused == true) | .$1"
}

get_workspace_property_by_idx() {
    niri msg --json workspaces | jq -r ".[] | select(.idx == $1) | .$2"
}

window_ids() {
    niri_filter='.[]'
    while [ $# -gt 0 ]; do
        case "$1" in
            --filter)
                shift
                niri_filter="$niri_filter | select($1)"
                shift
                ;;
            --appid)
                shift
                niri_filter=".[] | select(.app_id | contains(\"$1\"))"
                shift
                ;;
            --title)
                shift
                niri_filter=".[] | select(.title | contains(\"$1\"))"
                shift
                ;;
            --workspace)
                shift
                if [ "$1" = "focused" ]; then
                    workspace_id=$(get_focused_workspace_property id)
                else
                    workspace_id=$(get_workspace_property_by_idx "$1" id)
                fi
                niri_filter="$niri_filter | select(.workspace_id == $workspace_id)"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    niri msg --json windows | jq -r "$niri_filter | .id"
}

windo() {
    action=""
    windo_ids_flags=""
    id_flag="--id"
    while [ $# -gt 0 ]; do
        case "$1" in
            --id-flag)
                shift
                id_flag="$1"
                shift
                ;;
            --extra-args)
                shift
                extra_args="$1"
                shift
                ;;
            --filter|--appid|--title|--workspace)
                windo_ids_flags="$windo_ids_flags $1 $2"
                shift
                shift
                ;;
            *)
                action="$action $1"
                shift
        esac
    done
    # shellcheck disable=SC2046,SC2086  # We want word splitting here.
    window_ids $windo_ids_flags | xargs -I{} niri msg action $action $extra_args "$id_flag" {}
}

optimal_grid_layout() {
    width=$1
    height=$2
    elements=$3
    aspect_ratio=$(echo "scale=2; $width / $height" | bc)
    rows=$(echo "scale=0; sqrt($elements * $aspect_ratio)/1" | bc)
    if [ "$rows" -eq 0 ]; then
        rows=1
    fi
    columns=$(echo "($elements + $rows - 1) / $rows" | bc)
    echo "$rows $columns"
}

tile() {
    read -r width height number_of_windows <<EOF
$(niri msg --json focused-output | jq -r '.logical | "\(.width) \(.height)"')
EOF
    windows_to_tile=$(window_ids "$@")
    number_of_windows=$(echo "$windows_to_tile" | wc -l)
    read -r rows columns <<EOF
$(optimal_grid_layout "$width" "$height" "$number_of_windows")
EOF
    current_workspace_idx=$(get_focused_workspace_property idx)
    windo "$@" --extra-args '--focus false' --id-flag --window-id \
        "move-window-to-workspace $current_workspace_idx"
}

spread() {
    windo "$@" --extra-args '--focus false' --id-flag --window-id \
        'move-window-to-workspace 255'
    niri msg action focus-workspace-down
}

sedconf() {
    sed -e "$@" "$XDG_CONFIG_HOME/niri/base.kdl" > "$XDG_CONFIG_HOME/niri/config.kdl"
    niri msg action load-config-file
}

niriush() {
    case "$1" in
        ids)
            shift
            window_ids "$@"
            exit 0
            ;;
        windo)
            shift
            windo "$@"
            exit 0
            ;;
        tile)
            shift
            tile "$@"
            exit 0
            ;;
        spread)
            shift
            spread "$@"
            exit 0
            ;;
        sedconf)
            shift
            sedconf "$@"
            exit 0
            ;;
        --help|-h)
            usage 0
            ;;
        *)
            echo "Unknown command: $1"
            usage 1
            ;;
    esac
}

niriush "$@"
