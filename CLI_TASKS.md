# Lean Tooling CLI Task Tracker

## Phase 1 – Foundation
- [x] Create `lean` bash wrapper with argument parsing and help output.
- [x] Wire `lean build` to `scripts/build_lean_image.sh`.
- [x] Wire `lean backtest` to `scripts/run_backtest.sh` (pass through extra args).
- [x] Wire `lean live`/`lean stop` to `scripts/run_live.sh` / `scripts/stop_live.sh`.
- [x] Wire `lean download` to ToolBox (`dotnet /Lean/ToolBox/...`).

## Phase 2 – UX Enhancements
- [x] Add `lean --version` and `lean --help` output mirroring official CLI tone.
- [x] Support reading defaults from `lean.json` (data folder, config file overrides).
- [x] Add error messaging when Docker or required env vars are missing.

## Phase 3 – Documentation & Examples
- [x] Document `lean` usage in README with sample commands.
- [x] Provide example env setup (`POLYGON_API_KEY`, optional IB credentials).
- [x] Add troubleshooting section (missing data, permissions, etc.).

## Phase 4 – Testing & Validation
- [x] Run smoke backtest via `./lean backtest ...` inside a consuming repo.
- [x] Verify `lean download` writes data to host-mounted folder.
- [x] Validate `lean live` handles reconnect/stop cycle via `docker compose` commands.

## Phase 5 – Optional Enhancements
- [x] Add `lean ps` (show running containers) and `lean logs` helpers.
- [ ] Consider tab completion script for bash/zsh.
- [ ] Package as pip module or brew tap for wider distribution (future).
