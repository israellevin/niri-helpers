# ned - niri event dispatcher

A simple CLI niri event dispatcher written in Rust which listens on the niri socket for incoming events and triggers commands when matching events are received.

## Installation

Either use the provided `mkniri.sh` script to build ned (and niri and xwayland-satellite) from source in a docker container (see the relevant [section in the README](./README.md#mkniri.sh) for more information), or build ned yourself with cargo:

```sh
cd ned
cargo build [CARGO OPTIONS]
```

Then copy the built binary from `./target/.../ned` to somewhere in your `PATH` and you should be good to go.

## Usage

```sh
ned REGEX COMMAND [REGEX COMMAND]...
```

Regular expressions are just standard Rust regexes. When an event is received, it is matched through every provided regular expression. For every match the corresponding command is triggered with the event data passed as a JSON string through standard input.

The command can be a comma delimited list of arguments (e.g. `/usr/bin/jq,-r,.WindowClosed.id`), a single word (no spaces, e.g. `/usr/bin/jq`) which will simply be executed, or a single string which will be passed to `sh -c` (e.g. `'echo Window closed with id $(jq -r .WindowClosed.id)'`).

To try it out, create the following script to handle `WindowClosed` events and save it under the succinct name `switch_window_if_workspace_empty.sh`:

```sh
#!/bin/sh
get() {
    niri msg --json "$1" | jq -r "$2"
}
workspace_id="$(get workspaces '.[] | select(.is_focused == true) | .id')"
[ "$workspace_id" ] || exit 0
num_of_windows="$(get windows '[.[] | select(.workspace_id == '"$workspace_id"') ] | length')"
[ "$num_of_windows" = 0 ] && niri msg action focus-window-previous
```

Make sure it is executable with `chmod +x switch_window_if_workspace_empty.sh`, and then run the following command to start listening for `WindowClosed` events and trigger the script when they are received:

```sh
ned WindowClosed ./switch_window_if_workspace_empty.sh
```

Now switch into an empty workspace, open a window there and then close it. You should see that the focus automatically switches to the previously focused window.
