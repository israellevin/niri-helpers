# niriu.sh - niri utilities script

A small bash script for easy management of niri windows, workspaces and configuration from the command line or (more likely) from key bindings.

- Collect all windows that match chosen criteria and send them to a chosen workspace on a chosen output, scatter them across multiple workspaces or even tile them to fit a chosen screen
- Run custom commands on windows that match chosen criteria, such as maximizing them, changing their opacity or closing them
- Dynamically add, remove, or toggle niri configuration lines on the fly without needing to edit anything manually

## Try it Out

If you already have niri installed and running and only want to give `niriu.sh` a quick try, you can download it to your current working directory and run it from there (after examining the code, of course), substituting `niriu.sh` with `bash niriu.sh` in the examples below:

```sh
curl -Lo niriu.sh https://raw.githubusercontent.com/israellevin/niriush/master/niriu.sh
bash niriu.sh help
```

All of the niriu.sh commands can be launched from key bindings defined with `spawn-sh`, and script errors will be sent as notifications when there is no terminal connected to standard error.

### Flock - Workspace Management

If you have a bunch of windows open on a bunch of workspaces and maybe even a bunch of outputs, you can run the following command to bring them all to your currently focused workspace:

```sh
niriu.sh flock
```

You can choose specific subsets of windows to collect by filtering by title, app-id, workspace, output or any filter that matches the window data niri provides:

```sh
niriu.sh flock --title firefox
niriu.sh flock --output HDMI-A-1 --app-id foot
niriu.sh flock --filter '.is_floating == true'
```

You can send the matching windows to different outputs and workspaces, so the following will collect all the windows on the currently focused workspace and move them to workspace 2 on the HDMI-A-1 output:

```sh
niriu.sh flock --output edP-1 --to-output HDMI-A-1 --to-workspace 2
```

You can also use different arrangement modes. The default "natural" mode just moves all the collected windows to a specific workspace, but you can also use "up" and "down" which scatters each window to its own workspace above or below the specified output (defaulting to the currently focused one). So the following will take all the windows on an HDMI output and scatter each to its own workspace on the top of the currently focused output:

```sh
niriu.sh flock --output HDMI-A-1 --mode up
```

Note that the "up" and "down" modes will scatter windows across multiple workspaces, so these two modes are mutually exclusive with the `--to-workspace` option.

And lastly, there is a somewhat experimental "fit" mode which will tile the collected windows in a grid calculated to fit them all on the targeted screen. So the following will collect all of your windows and try to fit them on the screen you are currently focused on:

```sh
niriu.sh flock --mode fit
```

While the following will tile all of the windows running foot with "vim" in the title and try to fit them on the "editors" workspace on the HDMI-A-1 output.

```sh
niriu.sh flock --app-id foot --title vim --to-output HDMI-A-1 --to-workspace editors --mode fit
```

### Windo - Mass Window Actions

The same window matching criteria can be used to perform actions on the matching windows (for a list of available actions, run `niri msg action --help`):

```sh
niriu.sh windo --appid firefox maximize-window-to-edges        # Maximize all firefox windows
niriu.sh windo --output HDMI-1-0 close-window                  # Close all windows on a monitor
niriu.sh windo --workspace 'chat' set-window-width '-20%'      # Decrease width of all windows on the "chat" workspace
niriu.sh windo --workspace focused toggle-window-rule-opacity  # Toggle opacity rule for focused workspace
niriu.sh windo --filter '.pid == 1234' focus-window            # Focus window with PID 1234
```

If you need to pass extra arguments to the action, you can use the `--extra-args` option, and if the action expects a different flag for window IDs instead of the default `--id`, you can specify that with the `--id-flag` option. For example, the following will move all windows to workspace 2 without focusing them, by passing `--focus false` as an extra argument to the `move-window-to-workspace` action, and using `--window-id` as the ID flag since that is what `move-window-to-workspace` expects:

```sh
niriu.sh windo --extra-args '--focus false' --id-flag '--window-id' move-window-to-workspace 2
```

### Conf - Dynamic Configuration Management

To avoid accidentally messing up your main configuration file, niriu.sh operates on a separate dynamic configuration file which needs to be included in the main niri configuration file (either see [Installation](#installation) for instructions or simply answer yes when running the command and allow the script to do it for you.

Operation is pretty straightforward, you can add, remove or toggle lines in the dynamic configuration file, as well as reset it completely:

```sh
niriu.sh conf --add 'animations { on; }'     # Add a line enabling animations to dynamic config
niriu.sh conf --rm 'animations { on; }'      # Remove that line
niriu.sh conf --toggle 'animations { on; }'  # Toggle that line
niriu.sh conf --reset                        # Remove all dynamic configuration lines
```

Multiple option can be used and will be applied in order, just make sure that each option takes exactly one string argument which will become a whole line in the configuration file. This functionality is sensitive to the exact formatting of the lines (`animations { on; }` is not the same as `animations { on;}`), but that's not a problem when you are running the commands from pre-defined key bindings.

## Installation

Just copy the script to somewhere in your `PATH` and make it executable, for example:

```sh
curl -Lo ~/.local/bin/niriu.sh https://raw.githubusercontent.com/israellevin/niriush/master/niriu.sh
chmod +x ~/.local/bin/niriu.sh
```

To enable the dynamic configuration manipulation features of `niriu.sh`, make sure to include the dynamic configuration file in your main niri configuration file. The easiest way to do this is to run the following command from a terminal and allow it to add the inclusion line automatically:

```sh
niriu.sh conf --reset
```

Or you can add the inclusion line manually to your `config.kdl` if you prefer:

```kdl
include "<full path to your XDG_CONFIG_HOME>/niri/niriush.kdl"
```

Make sure to replace `<full path to your XDG_CONFIG_HOME>` with the actual *full* path. The script will fail if the inclusion line is not found precisely as expected, so if you choose to add it manually make sure that the path is correct and that the line is formatted exactly as above.

## niriu.sh Usage

```plaintext
Usage: niriu.sh COMMAND [OPTIONS]... ARGUMENTS
Manage niri windows, workspaces, and configuration dynamically.
Commands:
  conf [OPTIONS]...           Manage dynamic niriush configuration
  flock [OPTIONS]...          Arranges matching windows on a workspace/output
  windo [OPTIONS]... ACTION   Perform ACTION on windows matching selection criteria
  help                        Show this help message and exit
Configuration manipulation options for 'conf' (can be combined - the effects are applied in order):
  --add LINE                  Add LINE (if not found) to the dynamic niriush configuration file
  --rm LINE                   Remove LINE (if found) from the dynamic niriush configuration file
  --toggle LINE               Toggle LINE in the dynamic niriush configuration file
  --reset                     Reset the dynamic niriush configuration file to default state
Window selection options for 'flock' and 'windo' (can be combined - windows must match all criteria):
  --workspace REFERENCE       Select windows by workspace index, name, or 'focused'
  --output REFERENCE          Select windows by output name or 'focused'
  --app-id APP_ID             Select windows by application ID regex (case insensitive)
  --title TITLE               Select windows by title regex (case insensitive).
  --filter JQ_FILTER          Select windows by custom jq filter
Target selection options for 'flock' ('--to-workspace' doesn't make sense for 'up'/'down' arrangements):
  --to-output OUTPUT          Name of output to move windows to (default is focused output)
  --to-workspace REFERENCE    Index or name of workspace to move windows to (default is focused workspace)
  --mode MODE                 Window arrangement: 'natural', 'up', 'down' and 'tile' (default is 'natural')
Action command options for 'windo':
  --extra-args ARGS           Additional arguments to pass to ACTION
  --id-flag FLAG              Specify the flag to use for specifying window IDs in ACTION (default is --id)
General Options:
  --help, -h                  Show this help message and exit
```
