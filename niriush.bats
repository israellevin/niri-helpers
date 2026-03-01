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
    get windows "$1" "title == \"$TEST_TITLE\"" "$@"
}

countwin() {
    getwin id "$@" | wc -w
}

windo() {
    local action="$1"
    shift
    getwin id "$@" | xargs -I{} niri msg action "$action" --id {}
}


setup_file() {
    INITIAL_WINDOW_ID="$(get windows id 'is_focused == true')"
    for windo_index in $(seq 1 "$NUMBER_OF_TEST_WINDOWS"); do
        foot -f 'mono:size=32' -T niriushtest sh -c "echo -n '$windo_index'; sleep infinity 3>&-" 3>&- &
        sleep 0.1
    done
}

teardown_file() {
    windo close-window
    niri msg action focus-window --id "$INITIAL_WINDOW_ID"
}

setup() {
    cd "$(dirname "$BATS_TEST_FILENAME")" || exit 1
    load './test/test_helper/bats-support/load'
    load './test/test_helper/bats-assert/load'
}

@test 'show usage' {
    run $NIRIUSH --help
    assert_output --partial 'Manage niri windows, workspaces, and configuration dynamically'
}
