# Lean Tooling

Reusable Lean engine build and runtime assets shared across HumbleBot projects.

## Contents
- `Dockerfile` – multi-stage build that compiles Lean and the Polygon data source from source.
- `LeanEngine/` – QuantConnect Lean fork (submodule).
- `LeanDataSource.Polygon/` – Polygon data source fork (submodule).
- `scripts/` – helper scripts for building images and orchestrating backtest/live runs.

## Usage

### Initialize
From the consumer repository:

```bash
git submodule update --init --recursive
```

### Lean CLI Wrapper

The repository ships a `lean` CLI that mirrors the most common Lean CLI workflows while using the Docker assets built here.

```bash
# Build Lean engine image from source
./lean build

# Run a backtest (uses lean/<project>/config.json by default)
./lean backtest Nexora -- --start-date 2024-10-01 --end-date 2024-10-02
# Results land in lean/Nexora/backtests/<UTC timestamp>/

# Launch live trading (ensure POLYGON_API_KEY and brokerage env vars are set)
./lean live Nexora

# Download data via ToolBox
./lean download PolygonDataDownloader --ticker TSLA --from 2024-10-01 --to 2024-10-02 --resolution Minute

# Bootstrap the Interactive Brokers Gateway binaries (run once per machine)
./lean ib-gateway download --version stable

# Inspect containers / stop live sessions
./lean ps
./lean stop
```

Defaults such as the Lean project directory (`lean/`) and data folder are inferred from `lean/lean.json`. Override paths with environment variables: `LEAN_PROJECT_ROOT`, `LEAN_DIR`, or `LEAN_CONFIG`.

Backtests automatically mimic the upstream Lean CLI layout: each run writes logs, summaries, and artifacts under `lean/<Project>/backtests/<UTC timestamp>/` (or `lean/backtests/<UTC timestamp>/` if the config sits at the root).

Commands run detached (`docker compose run --detach …`) by default so the CLI prompt returns immediately. Tail progress via `docker logs -f <container>` or the timestamped log file. To force attached execution, export `LEAN_ATTACH=1` before invoking `./lean …`.

### Environment Variables

Set the required credentials before invoking live/data commands:

```bash
export POLYGON_API_KEY="<your key>"
# Optional brokerage variables:
export IB_USER_NAME=...
export IB_ACCOUNT=...
export IB_PASSWORD=...
```

### Troubleshooting

- **Missing docker compose** – install Docker Desktop or `docker-compose` and re-run.
- **Data folder not found** – ensure the host data directory defined in `lean/lean.json` exists or mount a volume at `/lean-data`.
- **Live session fails immediately** – verify credentials (POLYGON_API_KEY, brokerage) and that only one container is running (`./lean ps`).

To update Lean or Polygon source, update the submodules inside this tooling repo and commit the new SHAs.
