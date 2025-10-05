# Lean Tooling CLI Task Tracker

## Phase 1 – Foundation
- [ ] Create `lean` bash wrapper with argument parsing and help output.
- [ ] Wire `lean build` to `scripts/build_lean_image.sh`.
- [ ] Wire `lean backtest` to `scripts/run_backtest.sh` (pass through extra args).
- [ ] Wire `lean live`/`lean stop` to `scripts/run_live.sh` / `scripts/stop_live.sh`.
- [ ] Wire `lean download` to ToolBox (`dotnet /Lean/ToolBox/...`).

## Phase 2 – UX Enhancements
- [ ] Add `lean --version` and `lean --help` output mirroring official CLI tone.
- [ ] Support reading defaults from `lean.json` (data folder, config file overrides).
- [ ] Add error messaging when Docker or required env vars are missing.

## Phase 3 – Documentation & Examples
- [ ] Document `lean` usage in README with sample commands.
- [ ] Provide example env setup (`POLYGON_API_KEY`, optional IB credentials).
- [ ] Add troubleshooting section (missing data, permissions, etc.).

## Phase 4 – Testing & Validation
- [ ] Run smoke backtest via `./lean backtest ...` inside a consuming repo.
- [ ] Verify `lean download` writes data to host-mounted folder.
- [ ] Validate `lean live` handles reconnect/stop cycle via `docker compose` commands.

## Phase 5 – Optional Enhancements
- [ ] Add `lean ps` (show running containers) and `lean logs` helpers.
- [ ] Consider tab completion script for bash/zsh.
- [ ] Package as pip module or brew tap for wider distribution (future).

