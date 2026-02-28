# niri helpers

Shell based support to make life with niri even better!

## niriu.sh - niri user shell helper

A bash script for easy management of niri windows, workspaces and configuration from the command line or (more likely) from key bindings.

- Collect all windows that match chosen criteria and send them to a chosen workspace on a chosen output, scatter them across multiple workspaces or even tile or float them to fit a chosen screen
- Run custom commands on windows that match chosen criteria, such as maximizing them, changing their opacity or closing them
- Dynamically add, remove, or toggle niri configuration lines on the fly without needing to edit anything manually

To learn more about how to use it, or just to play with it without installing or building anything new, just skip to the [niriu.sh docs](./niriush.md).

## ned

A simple CLI niri event dispatcher written in Rust which listens on the niri socket for incoming events and triggers commands when matching events are received.

This is extremely powerful (in theory you could use it to write a whole new window manager on top of niri) and that makes it very easy to screw up your system - specifically to throw it into an infinite loop of events which trigger commands which trigger more events and so on.

My humble usage example is listening for the `WindowClosed` event, then checking if there are any windows left on the currently focused workspace, and if not, attempting to automatically switch to the previously focused window.

For more information see [ned docs](./ned/README.md).

## mkniri.sh

An easy to use wrapper around an embedded `Dockerfile` for building niri, xwayland-satellite and ned from source in a docker container, optionally invalidating the build cache, and then copying the built binaries to a local `./build` directory (from which you can easily copy them to somewhere in your `PATH` or just run them from there).

```text
Usage: ./mkniri.sh [clean] [--branch <branch>] [--repo <repo>]
  clean: Force rebuild of niri by using a new build argument.
  --branch <branch>: Specify the branch of the niri repository to use (default: main).
  --repo <repo>: Specify the repository URL of niri to use (default: https://github.com/niri-wm/niri).
```

## Requirements

- `niri` window manager with `niri msg` command available
- `bash` for running scripts
- `jq` for JSON processing
- `notify-send` with a running notification daemon for sending notification on errors (optional)
- `docker` for building niri (optional, only needed if you want to build niri from source)
