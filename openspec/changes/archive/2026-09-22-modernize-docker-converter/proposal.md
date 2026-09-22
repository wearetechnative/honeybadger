## Why

The `Dockerfile` has not been touched since 2026-02-09. Since then the audit pipeline moved on twice: the Python converter became the default (2026-03-31, `c9489dc`) and `neofetch` was replaced by `fastfetch` (2026-07-14, `c0db247`). The archived `use-python-lynis-converter` design explicitly listed *"Rewriting the Docker-based converter or Dockerfile"* as a non-goal, so the drift was parked, not fixed.

The result is an image that builds roughly 1 GB of tooling to emit a single JSON file:

- `wkhtmltopdf`, `texlive-latex-base`, `texlive-latex-recommended`, `pandoc` and seven X11/font libraries are installed, but `lynis-report-converter.pl` never invokes any of them in any mode. Its PDF path uses `HTML::HTMLDoc` (the `htmldoc` package). These are leftovers of a PDF pipeline that no longer exists in `RUNME.sh`.
- All format-specific Perl modules are lazily `require`d inside per-format branches (`JSON` at l.233, `XML::Writer` at l.318, `Excel::Writer::XLSX` at l.420, `HTML::HTMLDoc` at l.2415). The JSON path — the only path `RUNME.sh` uses — needs `libjson-perl` alone.
- `FROM debian:latest` is unpinned while the wkhtmltopdf `.deb` is hardcoded to `bookworm_amd64`, so the build drifts and silently produces a broken image on arm64: `dpkg -i` fails, `|| apt-get install -f -y` swallows the failure, and the build reports success.
- The converter is fetched from `master.zip`, so the image contains whatever was on master that day.

Separately, `RUNME.sh:128` guards the image rebuild with `[ Dockerfile -nt "$output" ]`, but `$output` is a directory created two lines earlier. The condition is never true, so editing the `Dockerfile` never triggers a rebuild.

Documentation still describes the pre-March world: `README.md:13-15` lists Docker as required and `neofetch` as a dependency, and `openspec/project.md` (l.41, l.306, l.375) does the same.

## What Changes

- **Slim the image**: drop `wkhtmltopdf` and its X11/font dependencies, `texlive-latex-base`, `texlive-latex-recommended`, `pandoc`, `cpanminus` and the `Excel::Writer::XLSX` CPAN build. Keep `libjson-perl` for the JSON path. Expected size drop from ~1 GB to roughly 150 MB, with no loss of reachable functionality.
- **Pin the base image**: `debian:latest` becomes `debian:bookworm-slim`.
- **Pin the converter**: replace the `master.zip` download with a checkout of commit `7a26d37cc3a0ca53ea259eee2b23f1e165ea4e6b`.
- **Make the build architecture-neutral**: with the amd64-only `.deb` gone, the image builds on both `amd64` and `arm64`.
- **Fix the dead rebuild branch** in `RUNME.sh` so a changed `Dockerfile` actually rebuilds the image.
- **Refresh documentation**: `README.md` prerequisites (Docker optional, `fastfetch` not `neofetch`) and `openspec/project.md` dependency lists.
- **Correct the config comment**: `.honeybadger.conf.example` claims the Docker converter "supports HTML/PDF/Excel output"; via honeybadger it does not, because `CMD` is hardcoded to `-j` and `RUNME.sh` never overrides it.
- **CHANGELOG**: add a `## NEXT VERSION` section describing the above.

## Capabilities

### Modified Capabilities

- `python-lynis-converter`: the Docker fallback gains requirements on image composition, pinning and architecture support, and the misleading claim about extra output formats is corrected.
- `dependency-validation`: the required-dependency list is corrected — `docker` is conditional and `neofetch` is now `fastfetch`.

## Impact

- **Dockerfile**: substantially rewritten; no behavioural change to the JSON output it produces.
- **RUNME.sh**: one-line fix to the rebuild guard in `audit`.
- **README.md, openspec/project.md, CHANGELOG.md, .honeybadger.conf.example**: documentation corrections.
- **Users with an existing `wearetechnative/lynis-report-converter:latest` image**: the fixed rebuild guard means their next audit with `USE_DOCKER_CONVERTER=true` rebuilds the image once.
- **No change** to the default audit path, which uses the Python converter and never touches Docker.
