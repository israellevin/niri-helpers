# ned - niri event dispatcher

A simple CLI niri event dispatcher written in Rust which listens on the niri socket for incoming events and triggers commands when matching events are received.

## Installation

Either use the provided `mkniri.sh` script to build ned (and niri and xwayland-satellite) from source in a docker container (see the relevant [section in the README](./README.md#mkniri.sh) for more information), or build ned yourself with cargo:

```sh
cd ned
cargo build [CARGO OPTIONS]
```

Then copy the built binary from `./target/.../ned` to somewhere in your `PATH` and you should be good to go.

## Try it out

Once you have installed ned, assuming you have niri running with IPC support and jq installed, you should be able to run the examples provided in the `./examples` directory directly from your terminal (hit Ctrl+C to stop them):

```sh
./examples/float_magnet.sh
```

Any floating windows you see will "stick" to your viewpoint and follow you around as you switch workspaces.

```sh
./examples/noempty.sh
```

Every time you close the last window on a workspace, you will automatically switch to the most recently focused window found, so you won't be left staring at an empty workspace.

The scripts below also require the `niriu.sh` utility script included in this repository, so make sure to copy it to somewhere in your `PATH` before running them.

```sh
./examples/showlayout.sh
```

Whenever you switch to a keyboard layout other than the default one, a blue border will be added to the focused window as a visual indicator of the current layout. When you switch back to the default layout, the border will be removed.

```sh
./examples/magnet.sh
```

This is a more advanced version of the first magnet example which uses `niriu.sh flock` to move windows. It passes any arguments provided to the `niriu.sh flock` command, so the argument-less usage above will cause all windows on any workspace you visit to follow you from that point on to any workspace you switch to.

That's a bit silly, of course, but the following will make floating windows follow you, just like the first example, but it will also arrange and resize them to fit on the right half of the screen:

```sh
./examples/magnet.sh --floating --mode float right
```

Or make any windows with "vim" in the title that you pass follow you into the tiling layout of whatever workspace you move to:

```sh
./examples/magnet.sh --title vim --mode tile
```

Or force them to float and arrange and resize them to fit on the top quarter of the screen with zero padding between them:

```sh
./examples/magnet.sh --title vim --mode float up 25 0
```

## Usage

```sh
ned REGEX COMMAND [REGEX COMMAND]...
```

Regular expressions are just standard Rust regular expressions. When an event is received, it is matched through every provided regular expression. For every match the corresponding command is triggered with the event data passed as a JSON string through standard input. ned will run indefinitely and continue to spawn commands in response to events until it is killed.

The command can be a comma delimited list of arguments (e.g. `/usr/bin/jq,-r,.WindowClosed.id`), a single word (no spaces, e.g. `/usr/bin/jq`) which will simply be executed, or a single string which will be passed to `sh -c` (e.g. `'echo Window closed with id $(jq -r .WindowClosed.id)'`).

The standard output and error streams of the triggered commands are transparently forwarded to ned's standard output and error, which is very useful for debugging your scripts.

The environment variable `NED_PID` will be set inside the spawned processes to the PID of the ned process. This is very handy when debugging multiple running instances and be used for killing ned from within a script, but also provides a simple way to check from within a script whether it was called by ned or manually.

The `NED_PID` variable allows for an ergonomic utility header on top of your scripts which binds them to ned when called manually as well as documents the event pattern the script is meant to handle:

```sh
[ "$NED_PID" ] || exec ned EventPattern "$0" ...
```

All of the above examples use this pattern, which is why you can run them directly. If, however, you wish to bind multiple commands to multiple event patterns, it is more economical to run them with a single ned process like so:

```sh
ned \
    WindowClosed noempty.sh \
    KeyboardLayoutSwitched showlayout.sh \
    Workspace 'magnets.sh --floating --mode float right'
```

Or, from within the niri configuration file:

```kdl
spawn-at-startup "ned" \
    "WindowClosed" "niri_noempty.sh" \
    "KeyboardLayoutSwitched" "niri_showlayout.sh" \
    "Workspace" "niri_magnet.sh --floating --mode float right"
```
