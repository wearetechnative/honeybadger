## 1. Repair Target Spec Structure (blocks archiving)

`openspec/specs/dependency-validation/spec.md` was archived with its delta headers intact: it contains two `## ADDED Requirements` headers and no `## Requirements` section, so all four of its requirements are invisible to `openspec validate`, `list` and `archive`. This change's `dependency-validation` delta cannot be archived until it is fixed. Pre-existing defect, unrelated to the Docker work.

- [x] 1.1 Confirm the defect: `openspec validate modernize-docker-converter --strict` reports "target spec is structurally invalid"
- [x] 1.2 Replace the `## ADDED Requirements` header at line 3 of `openspec/specs/dependency-validation/spec.md` with a `## Purpose` section followed by `## Requirements`
- [x] 1.3 Remove the second `## ADDED Requirements` header at line 40, so all four requirements sit inside the single `## Requirements` section
- [x] 1.4 Verify the requirement bodies and scenarios are otherwise unchanged (`git diff` should show only header edits)
- [x] 1.5 Re-run `openspec validate modernize-docker-converter --strict` and confirm the INFO block is gone
- [x] 1.6 Check the remaining capabilities in `openspec/specs/` for the same defect: `grep -l '^## \(ADDED\|MODIFIED\|REMOVED\) Requirements' openspec/specs/*/spec.md` — repair any others found

## 2. Baseline Capture

- [x] 2.1 Build the current image and tag it `wearetechnative/lynis-report-converter:pre-slim`
- [x] 2.2 Record its size: `docker image inspect --format '{{.Size}}' wearetechnative/lynis-report-converter:pre-slim`
- [x] 2.3 Capture reference output from the committed fixture: `docker run --rm -v $PWD/lynis.dat:/data/lynis-report.dat:ro wearetechnative/lynis-report-converter:pre-slim | jq -S . > /tmp/baseline.json`

## 3. Slim and Pin the Dockerfile

- [x] 3.1 Change `FROM debian:latest` to `FROM debian:bookworm-slim`
- [x] 3.2 Remove the `wkhtmltopdf` download/install instruction entirely (the `wget`/`dpkg -i`/`apt-get install -f` block)
- [x] 3.3 Remove the X11 and font packages that existed only for wkhtmltopdf: `fontconfig`, `libfreetype6`, `libjpeg62-turbo`, `libpng16-16`, `libx11-6`, `libxcb1`, `libxext6`, `libxrender1`, `xfonts-75dpi`, `xfonts-base`
- [x] 3.4 Remove `texlive-latex-base`, `texlive-latex-recommended` and `pandoc`
- [x] 3.5 Remove the `cpanm --notest --quiet Excel::Writer::XLSX` instruction and the `cpanminus` package
- [x] 3.6 Remove `libxml-writer-perl` and `libarchive-zip-perl`; keep `libjson-perl`
- [x] 3.7 Replace `wget`/`unzip` with `git` in the package list
- [x] 3.8 Replace the `master.zip` download with a shallow clone pinned to `7a26d37cc3a0ca53ea259eee2b23f1e165ea4e6b`, retaining the repository URL in a comment above it
- [x] 3.9 Drop the `perl Makefile.PL && make && make install` sequence and the `make` package; copy `lynis-report-converter.pl` to `/usr/local/bin/` and `chmod +x` it
- [x] 3.10 Verify `ENTRYPOINT` and `CMD` are unchanged
- [x] 3.11 Confirm no remaining instruction downloads an architecture-specific artifact, and no failure is absorbed by a trailing `||`

## 4. Fix the Rebuild Guard in RUNME.sh

- [x] 4.1 In `audit`, replace the `[ Dockerfile -nt "$output" ]` condition with a SHA-256 comparison against an `hb.dockerfile.sha` label stamped into the image at build time (see design decision 6)
- [x] 4.2 Verify the `$output` directory is no longer referenced by the rebuild condition
- [x] 4.3 Confirm the "Using cached Docker image" branch still runs when the `Dockerfile` is unchanged

## 5. Documentation

- [x] 5.1 `README.md:13` — change **Docker** from "Container runtime (required)" to optional, noting it is only needed when `USE_DOCKER_CONVERTER=true`
- [x] 5.2 `README.md:15` — replace **neofetch** with **fastfetch**
- [x] 5.3 `README.md` — add `python3` to the required dependencies
- [x] 5.4 `.honeybadger.conf.example:26` — remove the claim that the Docker converter "supports HTML/PDF/Excel output"; state that it produces JSON only and exists as a cross-check on the Python converter
- [x] 5.5 `openspec/project.md:41` — replace `neofetch` with `fastfetch` in the dependency list
- [x] 5.6 `openspec/project.md:306` — correct the required-dependency line to `lynis, fastfetch, jq, curl, tar, sed`, with `docker`/`python3` conditional on converter mode
- [x] 5.7 `openspec/project.md:375` — replace the neofetch reference link with fastfetch
- [x] 5.8 `openspec/project.md` — check lines 116, 150, 295 and 362 for stale `neofetch.json` references and correct where they describe current behaviour

## 6. CHANGELOG

- [x] 6.1 Add a `## NEXT VERSION` section to `CHANGELOG.md` if absent
- [x] 6.2 Under `### Changed`, describe **Slimmed Docker converter image** (dead PDF/LaTeX/Excel tooling removed, ~1 GB to ~150 MB) and **Pinned Docker build** (bookworm-slim base, converter pinned to a commit)
- [x] 6.3 Under `### Fixed`, describe **Docker image rebuild detection** (the guard compared against the output directory and never fired) and **arm64 image builds** (the amd64-only wkhtmltopdf `.deb` failed silently)
- [x] 6.4 Under `### Changed`, note the corrected documentation of Docker as an optional dependency and neofetch to fastfetch

## 7. Verification

- [x] 7.1 Build the new image: `docker build -t wearetechnative/lynis-report-converter:latest .`
- [x] 7.2 Record the new size and confirm a substantial reduction against task 1.2
- [x] 7.3 Run against the fixture and diff against the baseline: `docker run --rm -v $PWD/lynis.dat:/data/lynis-report.dat:ro wearetechnative/lynis-report-converter:latest | jq -S . | diff /tmp/baseline.json -` — expect no differences
- [x] 7.4 Build for arm64: `docker build --platform linux/arm64 -t lrc-arm64-test .` and confirm success
  - Host emulation had to be fixed first: `boot.binfmt.emulatedSystems` was set but NixOS defaults `preferStaticEmulators = false`, which registers the `qemu-aarch64-binfmt-P` shell wrapper with `flags: P` and no `F`. Without `F` the kernel resolves the interpreter inside the container's mount namespace, where `/run/binfmt/aarch64-linux` does not exist. Setting `boot.binfmt.preferStaticEmulators = true` switches to a static qemu and sets `fixBinary` (`binfmt.nix`: `fixBinary = mkDefault useStaticEmulator`), giving `flags: PF`.
  - Build succeeded: 195 MB arm64 image (169 MB on amd64), `Architecture: arm64`, perl reports `aarch64`.
  - Output verified byte-identical to the amd64 baseline on the `lynis.dat` fixture (169,914 bytes).
- [x] 7.5 Run `USE_DOCKER_CONVERTER=true ./RUNME.sh audit` end-to-end and confirm `lynis-report.json` is produced
  - Converter path verified against the real `/var/log/lynis-report.dat` using the exact `docker run` invocation from `RUNME.sh`: 141,285 bytes of valid JSON, byte-identical to the Python converter on the same input.
  - The surrounding full `lynis audit system` sweep was not re-run: it needs root and rescans the whole host, which is out of scope for verifying this change.
- [x] 7.6 Touch the `Dockerfile` and confirm the next `USE_DOCKER_CONVERTER=true` audit reports "Dockerfile changed, rebuilding image..."
  - Guard logic exercised in isolation across four states: unlabelled pre-existing image → rebuild; labelled and unchanged → cached; `touch` with identical content → cached; real content edit → rebuild. The old `[ Dockerfile -nt "$output" ]` condition was confirmed never to fire.
- [x] 7.7 Run `./RUNME.sh audit` with the default settings and confirm Docker is neither required nor invoked
  - `RUNME.sh:95-99` gates `checkdeps "docker"` behind `USE_DOCKER_CONVERTER=true` and `RUNME.sh:121` gates the entire Docker block the same way; the default path invokes `lib/lynis_report_converter.py`, verified to produce byte-identical JSON.
- [x] 7.8 Remove the temporary tags `pre-slim` and `lrc-arm64-test`
