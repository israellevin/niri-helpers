bats_require_minimum_version 1.5.0
NUMBER_OF_TEST_WINDOWS="${NUMBER_OF_TEST_WINDOWS:-5}"
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
    INITIAL_WINDOW_ID="$(get windows id 'is_focused == true')"
    export INITIAL_WINDOW_ID
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

# bats test_tags=windo
@test 'windo on all windows - single workspace' {
    run -1 $NIRIUSH windo --title "$TEST_TITLE" --floating move-window-to-floating
    [ "$(countwin)" -eq "$NUMBER_OF_TEST_WINDOWS" ]
    [ "$(countfloating)" -eq 0 ]
    run -0 $NIRIUSH windo --title "$TEST_TITLE" move-window-to-floating
    [ "$(countfloating)" -eq "$NUMBER_OF_TEST_WINDOWS" ]
}

# bats test_tags=windo
@test 'windo on all - scattered' {
    [ "$NUMBER_OF_TEST_WINDOWS" -lt 2 ] && skip
    scatter
    [ "$(countwin)" -eq "$NUMBER_OF_TEST_WINDOWS" ]
    [ "$(countfloating)" -eq 0 ]
    run -0 $NIRIUSH windo --title "$TEST_TITLE" move-window-to-floating
    [ "$(countfloating)" -eq "$NUMBER_OF_TEST_WINDOWS" ]
}

# bats test_tags=windo
@test 'windo on focused workspace' {
    [ "$NUMBER_OF_TEST_WINDOWS" -lt 2 ] && skip
    scatter
    [ "$(countwin)" -eq "$NUMBER_OF_TEST_WINDOWS" ]
    [ "$(countfloating)" -eq 0 ]
    niri msg action focus-window --id "${WINDOW_IDS%% *}"
    run -0 $NIRIUSH windo --title "$TEST_TITLE" --workspace focused move-window-to-floating
    [ "$(countfloating)" -eq 1 ]
}
