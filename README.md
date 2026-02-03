# niriush

Shell support to make life with niri even better

## Contents

- `Dockerfile`: Dockerfile for building niri (and xwayland-satellite) from source
- `make.sh`: Build niri (and xwayland-satellite) from source in a docker container
  - Supports `clean` (to invalidate the docker build cache) and `install`
- `niriu.sh`: Script helper for niri window management

## Usage

```plaintext
niriu.sh COMMAND [OPTIONS]... ARGUMENTS
Manage niri windows.
Commands:
  addconf STRING              Add STRING (if not found) to the dynamic niriush configuration file.
  rmconf STRING               Remove STRING (if found) from the dynamic niriush configuration file.
  sedconf SED_ARGS...         Modify the dynamic niriush configuration file using SED_ARGS.
  resetconf                   Reset the dynamic niriush configuration file to default state.
  windo [OPTIONS]... ACTION   Perform ACTION on windows matching selection criteria.
  fetch [OPTIONS]...          Pulls matching windows to focused or specified workspace.
  scatter [OPTION]            Move each matching windows to its own workspace.
  help                        Show this help message and exit.
Options for window management (can be combined to refine selection, so always used in conjunction):
  --filter JQ_FILTER          Apply a custom jq filter to select windows.
  --appid APP_ID              Select windows by application ID regex (case insensitive).
  --title TITLE               Select windows by title regex (case insensitive).
  --workspace REFERENCE       Select windows by workspace index, name, or 'focused'.
  --output REFERENCE          Select windows by output name or 'focused'.
  --id-flag FLAG              Specify the flag to use for specifying window IDs in ACTION (default: --id).
  --extra-args ARGS           Additional arguments to pass to ACTION.
Options for 'fetch':
  --target-workspace-idx IDX  Index of the workspace to fetch windows to (default: focused workspace).
  --tile                      Tile fetched windows on the focused workspace after fetching (experimental).
Option for 'scatter':
  --down                      Direction to scatter windows, default is up
General Options:
  --help, -h                  Show this help message and exit.
```

## Examples

Workspace management:

```sh
$ niriu.sh fetch --title "chat"         # Fetch all chat windows to focused workspace
$ niriu.sh scatter --workspace focused  # Scatter all windows from focused workspace to separate workspaces
$ niriu.sh fetch --workspace focused --appid foot --target-workspace-idx 2 --tile
  # Move all windows with "foot" in their app_id to workspace index 2 and fit them in an optimal grid
```

Window management:

```sh
$ niriu.sh windo --appid firefox maximize-window-to-edges        # Maximize all firefox windows
$ niriu.sh windo --workspace 3 close-window                      # Close all windows in workspace index 3
$ niriu.sh windo --filter '.pid == 1234' focus-window            # Focus window with PID 1234
$ niriu.sh windo --workspace focused toggle-window-rule-opacity  # Toggle opacity rule for entire workspace
$ niriu.sh windo --output HDMI-1-0 set-window-width '-20%'       # Decrease width of all windows on a monitor
$ niriu.sh windo --extra-args '--focus false' --id-flag '--window-id' move-window-to-workspace 2
  # Move all windows to workspace 2 without focusing them (as an extra argument to the action)
  # Note use of `--id-flag` because `move-window-to-workspace` expects a `--window-id` instead of the usual `--id`
```

Configuration manipulation:

```sh
$ niriu.sh addconf 'animations { on; }'  # Add a rule enabling animations to dynamic config
$ niriu.sh rmconf 'animations { on; }'   # Remove that rule
$ niriu.sh sedconf 's/on/off/'           # Change 'on' to 'off' in dynamic config
$ niriu.sh resetconf                     # Remove all dynamic rules
```

## Notes

When the script is run without a terminal connected to standard error (e.g. from a keybinding), error messages will be sent as notifications using `notify-send`.

Filtering rules are always used in conjunction, i.e. combined with AND, i.e. all conditions must be met for a window to match.

The configuration manipulation commands (`addconf`, `rmconf`, `sedconf`, `resetconf`) operate on a dynamic configuration file which must be included in the main niri configuration file. Running `niriu.sh resetconf` will create a default dynamic configuration file at `$XDG_CONFIG_HOME/niri/niriush.kdl` and check if it is included in the main niri configuration file at `$XDG_CONFIG_HOME/niri/config.kdl`. If the inclusion line is not found, the script will offer to add it automatically if standard input is connected to a terminal, otherwise it will simply error out.
