# Lean Tooling CLI Plan

## Goal
Provide a `lean` command inside this repository that mirrors the most common Lean CLI workflows (`lean build`, `lean backtest`, `lean live`, `lean download`) using the Docker image and tooling already shipped here.

## Scope
- Implement a self-contained `lean` wrapper script with subcommands.
- Ensure the wrapper works when the repository is used standalone or as a submodule.
- Support polygon-focused download workflows via QuantConnect ToolBox.
- Maintain compatibility with existing scripts (`scripts/build_lean_image.sh`, `scripts/run_backtest.sh`, etc.).

## Deliverables
1. `lean` executable (bash) exposing subcommands: `build`, `backtest`, `live`, `download`, `stop`.
2. Documentation (README section) describing installation and usage.
3. Optional: tab completion stub or help output consistent with Lean CLI.

## Open Questions
- Should we maintain configuration in `lean.json` similar to the official CLI, or rely on environment variables? (Default: read env, add optional `--config` flag.)
- Do we need additional subcommands (e.g., `lean logs`, `lean ps`) for status introspection? (Default: defer.)

## Risks / Considerations
- Docker must be available on host; script should gracefully fail otherwise.
- Consuming repos must mount data directories appropriately; document defaults.
- Keep the wrapper POSIX-compatible for macOS/Linux users.

