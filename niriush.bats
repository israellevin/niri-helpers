bats_require_minimum_version 1.5.0
NUMBER_OF_TEST_WINDOWS="${NUMBER_OF_TEST_WINDOWS:-5}"
NIRI_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
DYNAMIC_NIRIUSH_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/niri/niriush.kdl"
TEST_TITLE=niriushtest
NIRIUSH=./niriu.sh

get() {
    local object_type="$1"
    shift
    local property="$1"
    shift
    local filter='.[]'
    while [ $# -gt 0 ]; do
        filter="$filter | select(.$1)"
        shift
    done
    niri msg --json "$object_type" | jq -r "$filter | .$property"
}

getwin() {
    local property="$1"
    shift
    get windows "$property" "title == \"$TEST_TITLE\"" "$@"
}

countwin() {
    getwin id "$@" | wc -w
}

countfloating() {
    countwin 'is_floating == true'
}

windo() {
    local action="$1"
    shift
    getwin id "$@" | xargs -I{} niri msg action "$action" --id {}
}

setup_file() {
    cp "$NIRI_CONFIG_FILE" "$NIRI_CONFIG_FILE".bak
    cp "$DYNAMIC_NIRIUSH_CONFIG_FILE" "$DYNAMIC_NIRIUSH_CONFIG_FILE".bak

    INITIAL_WINDOW_ID="$(get windows id 'is_focused == true')"
    export INITIAL_WINDOW_ID

    mapfile -t output_names < <(get outputs name)
    NUMBER_OF_OUTPUTS="${#output_names[@]}"
    export NUMBER_OF_OUTPUTS
    if [ "$NUMBER_OF_OUTPUTS" -lt 2 ]; then
        echo "# Only one output detected, multi output tests will be skipped" >&3
    else
        PRIMARY_OUTPUT="$(niri msg --json focused-output | jq -r '.name')"
        if [ "$PRIMARY_OUTPUT" = "${output_names[0]}" ]; then
            SECONDARY_OUTPUT="${output_names[1]}"
        else
            SECONDARY_OUTPUT="${output_names[0]}"
        fi
        export PRIMARY_OUTPUT SECONDARY_OUTPUT
    fi

    [ "$NUMBER_OF_TEST_WINDOWS" -lt 2 ] && \
        echo "# Running with only $NUMBER_OF_TEST_WINDOWS test windows, some tests will be skipped" >&3
    for windo_index in $(seq 1 "$NUMBER_OF_TEST_WINDOWS"); do
        foot -f 'mono:size=32' -T niriushtest sh -c "echo -n '$windo_index'; sleep infinity 3>&-" 3>&- &
        sleep 0.1
    done
    mapfile -t window_ids < <(getwin id)
    echo "# Created $NUMBER_OF_TEST_WINDOWS test windows with IDs: ${window_ids[*]}" >&3
    # Bats doesn't support arrays as environment variables.
    export WINDOW_IDS="${window_ids[*]}"
}

teardown_file() {
    mv "$NIRI_CONFIG_FILE".bak "$NIRI_CONFIG_FILE"
    mv "$DYNAMIC_NIRIUSH_CONFIG_FILE".bak "$DYNAMIC_NIRIUSH_CONFIG_FILE"
    niri msg action load-config-file

    windo close-window
    echo "# Returning focus to initial window ID: $INITIAL_WINDOW_ID" >&3
    sleep 0.1
    niri msg action focus-window --id "$INITIAL_WINDOW_ID"
}

scatter() {
    for window_id in $WINDOW_IDS; do
        niri msg action move-window-to-workspace 255 --window-id "$window_id"
    done
}

setup() {
    load './test/test_helper/bats-support/load'
    load './test/test_helper/bats-assert/load'
    cd "$(dirname "$BATS_TEST_FILENAME")" || exit 1
    windo move-window-to-tiling
}

# bats test_tags=cli
@test 'show usage' {
    run -0 $NIRIUSH --help
    assert_output --partial 'Manage niri windows, workspaces, and configuration dynamically'
}

# bats test_tags=cli
@test 'conflicting options are rejected' {
    run -1 script -qec "$NIRIUSH flock --mode scatter --to-workspace 255" /dev/null
    assert_output --partial 'niriu.sh error: --to-workspace cannot be used with scatter mode'
}

# bats test_tags=conf
@test 'conf manipulates dynamic configuration file (--reset, --add, --rm, --toggle, --rm-re)' {
    local include_line="include \"$DYNAMIC_NIRIUSH_CONFIG_FILE\""
    grep -vxF "$include_line" "$NIRI_CONFIG_FILE" > "$NIRI_CONFIG_FILE".tmp
    mv "$NIRI_CONFIG_FILE".tmp "$NIRI_CONFIG_FILE"
    run -1 script -qec "echo n | $NIRIUSH conf --reset" /dev/null
    run -0 sh -c "echo y | socat - EXEC:'$NIRIUSH conf --reset',pty,setsid,ctty"
    grep -qxF "$include_line" "$NIRI_CONFIG_FILE"

    local test_line='// configuration test line'
    run -0 $NIRIUSH conf --add "$test_line"
    grep -qxF "$test_line" "$DYNAMIC_NIRIUSH_CONFIG_FILE"
    run -0 $NIRIUSH conf --add "$test_line"
    [ "$(grep -cxF "$test_line" "$DYNAMIC_NIRIUSH_CONFIG_FILE")" -eq 1 ]
    run -0 $NIRIUSH conf --rm "$test_line"
    [ "$(grep -cxF "$test_line" "$DYNAMIC_NIRIUSH_CONFIG_FILE")" -eq 0 ]
    run -0 $NIRIUSH conf --rm "$test_line"
    run -0 $NIRIUSH conf --toggle "$test_line"
    [ "$(grep -cxF "$test_line" "$DYNAMIC_NIRIUSH_CONFIG_FILE")" -eq 1 ]
    run -0 $NIRIUSH conf --toggle "$test_line"
    [ "$(grep -cxF "$test_line" "$DYNAMIC_NIRIUSH_CONFIG_FILE")" -eq 0 ]
    run -0 $NIRIUSH conf --add "$test_line"
    [ "$(grep -cxF "$test_line" "$DYNAMIC_NIRIUSH_CONFIG_FILE")" -eq 1 ]
    run -0 $NIRIUSH conf --rm-re "${test_line:0:5}.*"
    grep -cxF "$test_line" "$DYNAMIC_NIRIUSH_CONFIG_FILE" || true >&3
    [ "$(grep -cxF "$test_line" "$DYNAMIC_NIRIUSH_CONFIG_FILE")" -eq 0 ]
}

# bats test_tags=windo
@test 'windo matches all test windows' {
    [ "$(countfloating)" -eq 0 ]
    run -0 $NIRIUSH windo --title "$TEST_TITLE" move-window-to-floating
    [ "$(countfloating)" -eq "$NUMBER_OF_TEST_WINDOWS" ]
    run -0 $NIRIUSH windo --title "$TEST_TITLE" move-window-to-tiling
    [ "$(countfloating)" -eq 0 ]
}

# bats test_tags=windo
@test 'windo matches and moves windows across workspaces' {
    [ "$NUMBER_OF_TEST_WINDOWS" -lt 2 ] && skip

    # Act when all windows are on a single workspace.
    run -1 $NIRIUSH windo --title "$TEST_TITLE" --floating move-window-to-floating
    [ "$(countfloating)" -eq 0 ]
    run -0 $NIRIUSH windo --title "$TEST_TITLE" move-window-to-floating
    [ "$(countfloating)" -eq "$NUMBER_OF_TEST_WINDOWS" ]

    # Reset and split across multiple workspaces.
    windo move-window-to-tiling
    [ "$(countfloating)" -eq 0 ]
    scatter

    # Act on multiple workspaces.
    run -0 $NIRIUSH windo --title "$TEST_TITLE" move-window-to-floating
    [ "$(countfloating)" -eq "$NUMBER_OF_TEST_WINDOWS" ]

    # Match only focused workspace.
    niri msg action focus-window --id "${WINDOW_IDS%% *}"
    run -0 $NIRIUSH windo --title "$TEST_TITLE" --workspace focused move-window-to-tiling
    [ "$(countfloating)" -eq $((NUMBER_OF_TEST_WINDOWS - 1)) ]

    # Match only another workspace.
    local target_workspace_idx
    target_workspace_idx="$(get workspaces idx 'is_focused == true')"
    niri msg action focus-window --id "${WINDOW_IDS##* }"
    run -0 $NIRIUSH windo --title "$TEST_TITLE" --workspace "$target_workspace_idx" move-window-to-floating
    [ "$(countfloating)" -eq "$NUMBER_OF_TEST_WINDOWS" ]
}
