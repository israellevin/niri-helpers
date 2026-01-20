#!/usr/bin/bash
usage() {
    cat <<EOF
Usage: $0 COMMAND [OPTIONS]... ARGUMENTS
Manage niri windows.
Commands:
  ids [OPTIONS]...           Output IDs of windows matching criteria.
  windo [OPTIONS]... ACTION  Perform ACTION (a single string argument) on windows matching criteria.
  addconf STRING             Add STRING (if not found) to the dynamic niriush configuration file.
  rmconf STRING              Remove STRING (if found) from the dynamic niriush configuration file.
  sedconf SED_ARGS...        Modify the dynamic niriush configuration file using SED_ARGS.
  fetch                      Pulls matching windows to focused workspace.
  scatter                    Move each matching windows to its own workspace.
  wsprop INDEX PROPERTY      Output the PROPERTY of the workspace at INDEX.
  focwsprop PROPERTY         Output the PROPERTY of the focused workspace.
  winprop ID PROPERTY        Output the PROPERTY of the window with ID.
  focwinprop PROPERTY        Output the PROPERTY of the focused window.
Options for 'ids' and 'windo':
  --filter JQ_FILTER         Apply a custom jq filter to select windows.
  --appid APP_ID             Select windows by application ID regex (case insensitive).
  --title TITLE              Select windows by title regex (case insensitive).
  --workspace WORKSPACE_IDX  Select windows by workspace index or 'focused' for the focused workspace.
Options for 'windo':
  --id-flag FLAG             Specify the flag to use for window IDs in 'windo' ACTION (default: --id).
  --extra-args ARGS          Additional arguments to pass to the 'windo' ACTION.
Options for 'fetch':
  --tile                     Tile fetched windows on the focused workspace after fetching (experimental).
Options for 'scatter':
  --direction DIR            Direction to scatter windows: 'down' (default) or 'up'
General Options:
  --help, -h                 Show this help message and exit.
EOF
    exit "$1"
}

get() {
    local object_type="$1"
    shift
    local property="$1"
    shift
    local filter='.[]'
    while [ $# -gt 0 ]; do
        filter="$filter | select($1)"
        shift
    done
    niri msg --json "$object_type" | jq -r "$filter | .$property"
}

focused_workspace_property() {
    get workspaces "$1" '.is_focused == true'
}

workspace_property_by_idx() {
    get workspaces "$2" '.idx == '"$1"
}

focused_window_property() {
    get windows "$1" '.is_focused == true'
}

window_property_by_id() {
    get windows "$2" '.id == '"$1"
}

window_ids() {
    local filters=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --filter)
                shift
                filters+=("$1")
                shift
                ;;
            --appid)
                shift
                filters+=('.app_id | test("'"$1"'"; "i")')
                shift
                ;;
            --title)
                shift
                filters+=('.title | test("'"$1"'"; "i")')
                shift
                ;;
            --workspace)
                shift
                if [ "$1" = "focused" ]; then
                    workspace_id=$(focused_workspace_property id)
                else
                    workspace_id=$(workspace_property_by_idx "$1" id)
                fi
                filters+=('.workspace_id == '"$workspace_id")
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    get windows id "${filters[@]}"
}

windo() {
    local action=""
    local windo_ids_flags=""
    local id_flag="--id"
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
    window_ids $windo_ids_flags | xargs -I{} niri msg action $action $extra_args $id_flag {}
}

optimal_grid_layout() {
    local width=$1
    local height=$2
    local elements=$3
    local aspect_ratio
    local rows
    local columns
    aspect_ratio=$(echo "scale=2; $width / $height" | bc)
    rows=$(echo "scale=0; sqrt($elements * $aspect_ratio)/1" | bc)
    if [ "$rows" -eq 0 ]; then
        rows=1
    fi
    columns=$(echo "($elements + $rows - 1) / $rows" | bc)
    echo "$rows $columns"
}

fetch() {
    local windows_to_fetch
    local number_of_windows
    local tile
    local width
    local height
    local rows
    local columns
    local windo_ids_flags
    while [ $# -gt 0 ]; do
        case "$1" in
            --tile)
                shift
                tile=true
                ;;
            --filter|--appid|--title|--workspace)
                windo_ids_flags="$windo_ids_flags $1 $2"
                shift
                shift
                ;;
            *)
                shift
        esac
    done

    # shellcheck disable=SC2046,SC2086  # We want word splitting here.
    windows_to_fetch=$(window_ids $windo_ids_flags)
    number_of_windows=$(echo "$windows_to_fetch" | wc -l)

    if [ "$tile" ]; then
        read -r width height < <( \
            niri msg --json focused-output | jq -r '.logical | "\(.width) \(.height)"')
        read -r rows columns < <(optimal_grid_layout "$width" "$height" "$number_of_windows")
    fi

    # Can't use `windo` here because workspace idx is relative and may change after moving each window.
    for window_id in $windows_to_fetch; do
        niri msg action \
            move-window-to-workspace "$(focused_workspace_property idx)" \
            --window-id "$window_id" --focus false
    done
    if [ "$tile" ]; then
        local current_window_id
        current_window_id=$(focused_window_property id)
        niri msg action focus-column-first
        for ((column = 0; column < columns; column++)); do
            niri msg action consume-window-into-column
            niri msg action consume-window-into-column
            niri msg action focus-column-right
        done
        niri msg action focus-window --id "$current_window_id"
        windo "$@" 'set-window-width 33%'
    fi
}

scatter() {
    local target_workspace_idx=0
    local windo_ids_flags
    local current_window_id
    while [ $# -gt 0 ]; do
        case "$1" in
            --direction)
                shift
                if [ "$1" = "up" ]; then
                    target_workspace_idx=0
                elif [ "$1" = "down" ]; then
                    target_workspace_idx=255
                else
                    show_error "Invalid direction: $1"
                fi
                ;;
            --filter|--appid|--title|--workspace)
                windo_ids_flags="$windo_ids_flags $1 $2"
                shift
                shift
                ;;
            *)
                shift
        esac
    done
    current_window_id=$(focused_window_property id)
    windo "$@" --extra-args '--focus false' --id-flag '--window-id' \
        "move-window-to-workspace $target_workspace_idx"
    niri msg action focus-window --id "$current_window_id"
}

sedconf() {
    sed -ie "$@" "$XDG_CONFIG_HOME/niri/niriush.dynamic.kdl"
    niri msg action load-config-file
}

addconf() {
    grep -q "$1" "$XDG_CONFIG_HOME/niri/niriush.dynamic.kdl" && return 1
    sedconf "\$a $1"
}

rmconf() {
    grep -q "$1" "$XDG_CONFIG_HOME/niri/niriush.dynamic.kdl" || return 1
    sedconf "/$1/d"
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
        addconf)
            shift
            addconf "$@"
            ;;
        rmconf)
            shift
            rmconf "$@"
            ;;
        sedconf)
            shift
            sedconf "$@"
            exit 0
            ;;
        fetch)
            shift
            fetch "$@"
            exit 0
            ;;
        scatter)
            scatter "$@"
            exit 0
            ;;
        wsprop)
            shift
            workspace_property_by_idx "$1" "$2"
            exit 0
            ;;
        focwsprop)
            shift
            focused_workspace_property "$1"
            exit 0
            ;;
        winprop)
            shift
            window_property_by_id "$1" "$2"
            exit 0
            ;;
        focwinprop)
            shift
            focused_window_property "$1"
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

show_error() {
    local error_message="Error: ${BASH_SOURCE[0]} failed in line ${BASH_LINENO[0]}"
    echo -e "$error_message" >&2
    notify-send -a niriush -u critical "$error_message"
    exit 1
}
trap show_error ERR
set -E
niriush "$@"
