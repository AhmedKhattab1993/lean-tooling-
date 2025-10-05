# Lean Tooling

Reusable Lean engine build and runtime assets shared across HumbleBot projects.

## Contents
- `Dockerfile` – multi-stage build that compiles Lean and the Polygon data source from source.
- `LeanEngine/` – QuantConnect Lean fork (submodule).
- `LeanDataSource.Polygon/` – Polygon data source fork (submodule).
- `scripts/` – helper scripts for building images and orchestrating backtest/live runs.

## Usage
From the consumer repository:

```bash
# Initialize nested submodules
git submodule update --init --recursive

# Build engine image
./scripts/build_lean_image.sh

# Run backtest
./scripts/run_backtest.sh Nexora/config.json
```

To update Lean or Polygon source, update the submodules inside this tooling repo and commit the new SHAs.
