# niriush

Shell scripts to make life with niri even better

- `build.sh`: Script to build niri (and xwayland-satellite) from source in a docker container
- `Dockerfile`: Dockerfile used by `build.sh` to create the build environment
- `niriu.sh`: Script helper for niri management
  - `ids`: List niri window IDs with different jq filtering options (sorting will come in future)
    - `niriu.sh ids --filter '.pid == 1234'` - will print the ID of the window with PID 1234
    - `niriu.sh ids --appid firefox` - will print IDs of all windows with "firefox" in their app_id (identical to `--filter '.app_id | contains("firefox")'`)
    - `niriu.sh ids --title "vi"` - will print IDs of all windows with "vi" in their title (identical to `--filter '.title | contains("vi")'`)
    - `niriu.sh ids --workspace 3` - will print IDs of all windows in workspace 3
    - `niriu.sh ids --workspace focused` - will print IDs of all windows in the currently focused workspace
  - `windo`: Perform a niri msg action on all matching windows (same filtering options as `ids`)
    - `niriu.sh windo --workspace focused 'set-window-width -20%'` - decrease width of all windows in the currently focused workspace by 20%
    - `niriu.sh windo --extra-args '--focus false' --id-flag --window-id move-window-to-workspace 2` - move all windows with the specified IDs to workspace 2 without focusing them (note the use of `--id-flag` because the `move-window-to-workspace` action expects a `--window-id` flag instead of the usual `--id`)
    - `niriu.sh windo --workspace focused toggle-window-rule-opacity` - toggle the window rule opacity for all windows in the currently focused workspace
  - `spread`: Spread windows across workspaces
  - `sedconf`: Edit the niri configuration file with sed commands
    - `niriu.sh sedconf 's|^// animations|animations|'` - uncomment the animations line in my niri config
  - `tile`: Work in progress: Tile windows in the current visible area
