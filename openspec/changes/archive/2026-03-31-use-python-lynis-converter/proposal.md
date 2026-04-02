## Why

The `wearetechnative/lynis-report-converter` project has been updated with a new Python-based converter (`lynis_report_converter.py`) that outputs JSON directly — no Docker, Perl, or heavy dependencies required. Currently, the `RUNME.sh audit` command builds and runs a Docker container with the legacy Perl-based converter, which adds complexity (Docker dependency, image builds, large image size). Switching to the Python script as the default simplifies the audit workflow and removes Docker as a hard requirement.

## What Changes

- **Default converter**: `RUNME.sh audit` will use the Python script `lynis_report_converter.py` instead of Docker by default.
- **Docker as opt-in alternative**: A new `USE_DOCKER_CONVERTER` boolean in `honeybadger.conf` allows users to fall back to the Docker-based converter if needed.
- **Reduced dependencies**: `docker` is no longer a required dependency for the default audit flow; `python3` (or `python`) is required instead.
- **Bundling/fetching the converter**: The Python script needs to be available locally — either bundled in the repo or fetched at runtime.
- **Config file update**: `.honeybadger.conf.example` gets the new `USE_DOCKER_CONVERTER` option.

## Capabilities

### New Capabilities

- `python-lynis-converter`: Integrate the Python-based lynis report converter as the default conversion method, with Docker as a configurable fallback.

### Modified Capabilities

_(none — no existing spec-level requirements change)_

## Impact

- **RUNME.sh**: The `audit` function changes its report conversion logic.
- **Dependencies**: `docker` becomes optional; `python3` becomes required by default.
- **Configuration**: New `USE_DOCKER_CONVERTER` setting in `.honeybadger.conf`.
- **Dockerfile**: Remains in repo for users who opt into Docker mode, but is no longer used by default.
