#!/usr/bin/bash
# shellcheck disable=SC2016  # I'm using backticks in output messages.

NIRIUSH=./niriu.sh
NUMBER_OF_TEST_WINDOWS=${1:-5}
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

[ "$NUMBER_OF_TEST_WINDOWS" -gt 2 ] 2> /dev/null || {
    echo -e "${RED}ERROR: NUMBER_OF_TEST_WINDOWS must be at least 3 to properly test workspace movement${RESET}"
    exit 1
}

expect() {
    local expect_error
    local is_setup_expectation
    local command_output
    local command_exit_code
    local failed
    [ "$1" = error ] && expect_error=true && shift
    if [ "$1" = setup ]; then
        is_setup_expectation=true
    else
        echo -n " - $1:"
    fi
    shift
    command_output="$("$@" 2>&1)"
    command_exit_code=$?
    if [ $command_exit_code != 0 ]; then
        [ -z "$expect_error" ] && failed=true
    else
        [ "$expect_error" ] && failed=true
    fi
    if [ "$failed" ]; then
        echo -e "$RED ERROR executing command:\n$*\nOutput:\n$command_output$RESET"
        [ "$is_setup_expectation" ] && echo "Setup expectation failed in line ${BASH_LINENO[0]} - aborting" && exit 1
    else
        [ -z "$is_setup_expectation" ] && echo -e "$GREEN PASS$RESET"
    fi
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

INITIAL_WINDOW_ID="$(get windows id '.is_focused == true')"

echo '=== Configuration management tests ==='

NIRI_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
DYNAMIC_NIRIUSH_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/niri/niriush.kdl"

cp "$NIRI_CONFIG_FILE" "$NIRI_CONFIG_FILE".bak
cp "$DYNAMIC_NIRIUSH_CONFIG_FILE" "$DYNAMIC_NIRIUSH_CONFIG_FILE".bak
restore_configs() {
    mv "$DYNAMIC_NIRIUSH_CONFIG_FILE".bak "$DYNAMIC_NIRIUSH_CONFIG_FILE"
    mv "$NIRI_CONFIG_FILE".bak "$NIRI_CONFIG_FILE"
}
trap restore_configs EXIT

line='// test-line'

expect error setup grep -qxF "$line" "$DYNAMIC_NIRIUSH_CONFIG_FILE"

$NIRIUSH conf --add "$line"
expect '`conf --add` adds line to dynamic config file' \
    grep -qxF "$line" "$DYNAMIC_NIRIUSH_CONFIG_FILE"

$NIRIUSH conf --add "$line"
expect '`conf --add` with existing line does not create duplicates' \
    [ "$(grep -cxF "$line" "$DYNAMIC_NIRIUSH_CONFIG_FILE")" = 1 ]

$NIRIUSH conf --rm "$line"
expect error '`conf --rm` removes line from dynamic config file' \
    grep -qxF "$line" "$DYNAMIC_NIRIUSH_CONFIG_FILE"

$NIRIUSH conf --rm "$line"
expect error '`conf --rm` with non-existing line does not cause error' \
    grep -qxF "$line" "$DYNAMIC_NIRIUSH_CONFIG_FILE"

$NIRIUSH conf --toggle "$line"
expect '`conf --toggle` adds line if it does not exist' \
    grep -qxF "$line" "$DYNAMIC_NIRIUSH_CONFIG_FILE"

$NIRIUSH conf --toggle "$line"
expect error '`conf --toggle` removes line if it exists' \
    grep -qxF "$line" "$DYNAMIC_NIRIUSH_CONFIG_FILE"

grep -vxF "include \"$DYNAMIC_NIRIUSH_CONFIG_FILE\"" "$NIRI_CONFIG_FILE" > "$NIRI_CONFIG_FILE".tmp
mv "$NIRI_CONFIG_FILE".tmp "$NIRI_CONFIG_FILE"
expect error setup grep -qxF "include \"$DYNAMIC_NIRIUSH_CONFIG_FILE\"" "$NIRI_CONFIG_FILE"
niri msg action load-config-file > /dev/null 2>&1
echo testing-marker >> "$DYNAMIC_NIRIUSH_CONFIG_FILE"
expect setup grep -qxF testing-marker "$DYNAMIC_NIRIUSH_CONFIG_FILE"

echo y | socat - EXEC:"$NIRIUSH conf --reset",pty,setsid,ctty > /dev/null 2>&1
expect error '`conf --reset` restores include line in main config' \
    grep -qxF testing-marker "$DYNAMIC_NIRIUSH_CONFIG_FILE"
expect '`conf --reset` restores include line in main config' \
    grep -qxF "include \"$DYNAMIC_NIRIUSH_CONFIG_FILE\"" "$NIRI_CONFIG_FILE"

echo "=== Command line argument validation tests ==="

expect error 'conflicting flags are disallowed' \
    script -qec "$NIRIUSH flock --mode scatter --to-workspace 255" /dev/null

$NIRIUSH conf --add 'layout { empty-workspace-above-first false; }'
expect error 'unsupported flags are disallowed' \
    script -qec "$NIRIUSH flock --mode up" /dev/null
$NIRIUSH conf --rm 'layout { empty-workspace-above-first false; }'

restore_configs
niri msg action load-config-file > /dev/null 2>&1
trap - EXIT

echo '=== Window commands tests ==='

windo() {
    $NIRIUSH windo --title niriushtest "$@"
}

count_floating() {
    get windows is_floating '.title == "niriushtest"' | grep -c true
}

close_test_windows() {
    windo close-window
    niri msg action focus-window --id "$INITIAL_WINDOW_ID"
}
trap close_test_windows EXIT

niri msg action focus-workspace 255
for windo_index in $(seq 1 "$NUMBER_OF_TEST_WINDOWS"); do
    foot -f 'mono:size=32' -T niriushtest sh -c "echo '$windo_index'; sleep infinity" > /dev/null 2>&1 &
    sleep 0.1
done

mapfile -t test_window_ids < <(get windows id ".title == \"niriushtest\"")
expect setup [ "${#test_window_ids[@]}" =  "$NUMBER_OF_TEST_WINDOWS" ]
    expect setup [ "$(count_floating)" = 0 ]

windo move-window-to-floating
expect '`windo --title` applies action to all windows with matching title' \
    [ "$(count_floating)" =  "$NUMBER_OF_TEST_WINDOWS" ]

windo --workspace focused move-window-to-tiling
expect '`windo --workspace` applies action to all windows in workspace' \
    [ "$(count_floating)" = 0 ]

windo --tiled move-window-to-floating
expect '`windo --tiled` selects all tiled' \
    [ "$(count_floating)" =  "$NUMBER_OF_TEST_WINDOWS" ]

windo --floating move-window-to-tiling
expect '`windo --floating` selects all floating' \
    [ "$(count_floating)" = 0 ]

windo --focused move-window-to-floating
expect '`windo --focused` selects only focused' \
    [ "$(count_floating)" = 1 ]
windo --focused move-window-to-tiling
expect setup [ "$(count_floating)" = 0 ]

windo --unfocused move-window-to-floating
expect '`windo --unfocused` excludes focused' \
    [ "$(count_floating)" = $((NUMBER_OF_TEST_WINDOWS - 1)) ]

windo --filter '.is_floating == true' move-window-to-tiling
expect '`windo --filter` works' \
    [ "$(count_floating)" = 0 ]

echo '=== Workspace movement tests ==='

flock() {
    $NIRIUSH flock --title niriushtest "$@"
}

count_windows_in_workspace() {
    local ws_id="${1:-}"
    [ -z "$ws_id" ] && ws_id="$(get workspaces id '.is_focused == true')"
    get windows workspace_id ".workspace_id == $ws_id" | wc -w
}

expect setup [ "$(count_windows_in_workspace)" -eq  "$NUMBER_OF_TEST_WINDOWS" ]

flock --unfocused --to-workspace 255
expect '`flock --unfocused` does not move focused window' \
    [ "$(count_windows_in_workspace)" = 1 ]

windo --workspace focused move-window-to-floating
expect '`windo --workspace applies command only to windows in workspace`' \
    [ "$(count_floating)" = 1 ]

niri msg action focus-workspace-down
expect '`flock --unfocused` moves all unfocused windows to target workspace' \
    [ "$(count_windows_in_workspace)" = $((NUMBER_OF_TEST_WINDOWS - 1)) ]

windo --workspace focused move-window-to-floating
expect '`windo --workspace` applies command to all windows in new workspace' \
    [ "$(count_floating)" =  "$NUMBER_OF_TEST_WINDOWS" ]

flock --mode scatter
expect '`flock --mode scatter` moves each window to its own workspace' \
    [ "$(get windows workspace_id '.title == "niriushtest"' | sort -u | wc -w)" =  "$NUMBER_OF_TEST_WINDOWS" ]

flock
expect '`flock` with default mode moves all windows to current workspace' \
    [ "$(count_windows_in_workspace)" =  "$NUMBER_OF_TEST_WINDOWS" ]

windo --workspace focused move-window-to-tiling
expect '`windo --workspace` now applies to all windows again' \
    [ "$(count_floating)" = 0 ]

echo '=== Multi-output tests ==='
mapfile -t output_names < <(get outputs name)
if [ "${#output_names[@]}" -lt 2 ]; then
    echo -e "${YELLOW}WARN: Less than two outputs detected - multi-output tests will be skipped$RESET"
else
    expect setup [ "$(count_windows_in_workspace)" -eq  "$NUMBER_OF_TEST_WINDOWS" ]

    primary_output="$(niri msg --json focused-output | jq -r '.name')"
    if [ "$primary_output" = "${output_names[0]}" ]; then
        secondary_output="${output_names[1]}"
    else
        secondary_output="${output_names[0]}"
    fi
    echo "Using outputs: $primary_output and $secondary_output"

    flock --unfocused --to-output "$secondary_output" --to-workspace 255
    expect '`flock` moves selected windows out of focused workspace' \
        [ "$(count_windows_in_workspace)" = 1 ]

    mapfile -t test_workspaces < <(get windows workspace_id ".title == \"niriushtest\"" | sort -u)
    expect setup [ "${#test_workspaces[@]}" = 2 ]
    primary_workspace="$(get workspaces id '.is_focused == true')"
    if [ "$primary_workspace" = "${test_workspaces[0]}" ]; then
        secondary_workspace="${test_workspaces[1]}"
    else
        secondary_workspace="${test_workspaces[0]}"
    fi

    expect '`flock` moves selected windows into target workspace on target output' \
        [ "$(count_windows_in_workspace "$secondary_workspace")" = $((NUMBER_OF_TEST_WINDOWS - 1)) ]

    windo --output "$secondary_output" move-window-to-floating
    expect '`windo --output` applies only to windows on selected output' \
        [ "$(count_floating)" = $((NUMBER_OF_TEST_WINDOWS - 1)) ]

    flock --output "$secondary_output" --to-output "$secondary_output" --mode scatter

    secondary_output_workspace_ids="$(get workspaces id ".output == \"$secondary_output\"")"
    secondary_output_workspace_ids="$(tr '\n' ',' <<<"$secondary_output_workspace_ids")"
    secondary_output_workspace_ids="${secondary_output_workspace_ids%,}"
    number_of_arranged_workspaces="$( \
        get windows workspace_id ".workspace_id | IN($secondary_output_workspace_ids)" | \
        sort -u | \
        wc -w
    )"
    expect '`flock --mode scatter` creates a separate workspace for each flocked window' \
        [ "$number_of_arranged_workspaces" = $((NUMBER_OF_TEST_WINDOWS - 1)) ]

    mapfile -t secondary_output_window_ids < <(get windows id ".workspace_id | IN($secondary_output_workspace_ids)")
    flock --filter ".id == ${secondary_output_window_ids[0]}"
    expect '`flock` with a filter id moves a single window' \
        [ "$(count_windows_in_workspace)" = 2 ]
fi

echo "=== Visual test ==="
niri msg action focus-window --id "$INITIAL_WINDOW_ID"
echo -e "${CYAN}Visually verify that all $NUMBER_OF_TEST_WINDOWS test windows fit on the screen"
echo -e "Press any key (or wait) to continue, then ctrl-c (or wait) to finish the test$RESET"
timeout -f 5 bash -c 'read -sn1' > /dev/null 2>&1

niri msg action focus-window-previous
flock --mode tile fit
start_time=$(date +%s)
while [ "$(($(date +%s) - start_time))" -lt 5 ]; do
    for id in "${test_window_ids[@]}"; do
        [ "$(count_windows_in_workspace)" =  "$NUMBER_OF_TEST_WINDOWS" ] || break 2
        niri msg action focus-window --id "$id"
        sleep 0.1
    done
done

close_test_windows
trap - EXIT

exit 0
