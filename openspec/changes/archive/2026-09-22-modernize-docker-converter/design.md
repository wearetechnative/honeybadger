## Context

`USE_DOCKER_CONVERTER=true` is an opt-in fallback introduced by `use-python-lynis-converter` (2026-03-31). That change made the Python converter the default and deliberately left the `Dockerfile` alone (`design.md` Non-Goals: *"Rewriting the Docker-based converter or Dockerfile"*). Six months of accumulated drift is now being paid off.

The stated reason for keeping the fallback was *"Users who need the legacy Perl converter's extra formats can opt in"* (archived `design.md:34`). That rationale does not survive inspection: the image's `CMD` is `["-j", "-i", "/data/lynis-report.dat", "-o", "/dev/stdout"]` and `RUNME.sh:135` never overrides it. Through honeybadger the Docker path yields JSON and nothing else.

We keep the fallback anyway — the user's decision — but size it for what it actually does.

## Goals / Non-Goals

**Goals:**
- Reduce image size and build time to match the single reachable code path (JSON).
- Make the build reproducible: pinned base image, pinned converter commit.
- Make the build succeed or fail honestly on arm64 rather than silently producing a broken image.
- Fix the rebuild guard in `RUNME.sh` so `Dockerfile` edits take effect.
- Bring `README.md`, `openspec/project.md`, `.honeybadger.conf.example` and the specs back in line with reality.

**Non-Goals:**
- Removing the Docker fallback entirely (considered, rejected — see Decision 1).
- Restoring HTML/PDF/XLSX output to `RUNME.sh`.
- Changing the default audit path or the Python converter.
- Replacing `wkhtmltopdf` with a maintained PDF engine — nothing in the reachable path needs a PDF engine at all.

## Decisions

### 1. Keep the fallback, slim it rather than delete it

**Decision**: The `Dockerfile` and `USE_DOCKER_CONVERTER` stay; the image is stripped to the JSON path.

**Rationale**: Deleting it was the cheaper option and is what `ROADMAP.md` ("flake edition (skip docker stuff)") points toward, but keeping a working escape hatch costs little once the dead weight is gone. A ~150 MB image that builds in under a minute is cheap to maintain; a ~1 GB image that pulls texlive is not.

**Alternative considered**: Remove entirely. Rejected — retaining an independent second implementation is useful for cross-checking the Python converter's output when a `.dat` field is suspected of misparsing.

### 2. Determine dependencies from the lazy `require` sites, not `Makefile.PL`

**Decision**: Install `libjson-perl` only. Drop `libxml-writer-perl`, `libarchive-zip-perl`, `cpanminus` and `Excel::Writer::XLSX`.

**Rationale**: `lynis-report-converter.pl` uses `Module::Load::Conditional` and defers every format module to its own branch:

```
l.233   if ($json)    { require JSON;                  }   → libjson-perl
l.318   elsif ($xml)  { require XML::Writer;           }   → not reachable via CMD
l.420   elsif ($excel){ require Excel::Writer::XLSX;   }   → not reachable via CMD
l.2415  if ($pdf)     { require HTML::HTMLDoc;         }   → not reachable via CMD
```

Its top-level `use` statements (`strict`, `warnings`, `feature`, `Term::ANSIColor`, `Getopt::Long`, `Data::Dumper`, `Module::Load::Conditional`) are all core Perl. `Makefile.PL` declares `HTML::HTMLDoc` and `Excel::Writer::XLSX` as `PREREQ_PM`, but the current `Dockerfile` never installs `HTML::HTMLDoc` and the image works regardless — because `perl Makefile.PL` only warns on missing prerequisites and the build then `cp`s the script into place by hand. The `Makefile.PL`/`make`/`make install` sequence is decorative and is dropped along with `make`.

**Trade-off**: An operator who overrides `CMD` to request `-x`/`-E`/`-p` gets a module-load error instead of output. Acceptable: that path is undocumented, was never wired up, and the error names the missing module.

### 3. `debian:bookworm-slim`, pinned by tag

**Decision**: `FROM debian:bookworm-slim`.

**Rationale**: `debian:latest` floats across releases, which is how the bookworm-pinned `.deb` became a latent breakage. `-slim` is appropriate now that no X11 or font stack is needed. A tag rather than a digest keeps security updates flowing within the release; the reproducibility that matters here is the converter version, which Decision 4 pins exactly.

### 4. Pin the converter to a commit, fetched with `git`

**Decision**: Replace the `master.zip` download with a shallow `git` fetch of `7a26d37cc3a0ca53ea259eee2b23f1e165ea4e6b`, then copy `lynis-report-converter.pl` into `/usr/local/bin/`.

**Rationale**: `master.zip` makes the image contents a function of build date. A commit pin makes the Perl and Python converters independently versioned and auditable. `git` replaces `wget` + `unzip`, so both drop out of the dependency list.

**Trade-off**: `git` in the build stage adds weight. If this matters, a later change can move to a multi-stage build; at ~150 MB it does not yet.

### 5. Architecture neutrality falls out of Decision 2

**Decision**: No explicit `--platform` handling. Removing the amd64 `.deb` leaves only `arch: all` packages and a Perl script.

**Rationale**: The current silent-failure mode is the actual defect — `wget ... && dpkg -i ... || apt-get install -f -y && rm -f ...` parses as `(((wget && dpkg) || apt) && rm)`, so an architecture mismatch is absorbed by the `||` and the build reports success without wkhtmltopdf. With that instruction gone the failure mode disappears rather than being handled. Honeybadger runs on Apple Silicon laptops, so this is not hypothetical.

### 6. Rebuild guard compares Dockerfile content, not timestamps

**Decision**: Replace `[ Dockerfile -nt "$output" ]` with a comparison of the `Dockerfile`'s SHA-256 against a `hb.dockerfile.sha` label stamped into the image at build time.

**Rationale**: `$output` is created by `mkdir -p` two lines above the test, so `Dockerfile` can never be newer and the branch is unreachable. The intent was "rebuild when the Dockerfile changed since the image was built".

A timestamp comparison was the first candidate, but implementation showed it needs two dual-idiom fallbacks to stay portable — `stat -c %Y` / `stat -f %m` for the file and `date -d` / `date -j -f` for the image's RFC3339 `.Created` field. `RUNME.sh:255` already carries one such `stat -c … || stat -f …` pair, so macOS support is a live constraint, not a hypothetical one.

Hashing the content needs a single fallback pair (`sha256sum` / `shasum -a 256`) and is strictly more accurate: a fresh `git clone` rewrites mtimes without changing content, which a timestamp comparison would misread as a change and a checksum correctly ignores. Verified against all four states — unlabelled pre-existing image, labelled and unchanged, `touch` with identical content, and a real content edit.

**Trade-off**: Images built before this change carry no label, so the first `USE_DOCKER_CONVERTER=true` audit after upgrading rebuilds once. That is the intended behaviour — those images are the stale ones.

## Risks / Trade-offs

- **[Operator relied on an overridden `CMD` for HTML/PDF/XLSX]** → Breaks with a module-load error. Mitigation: undocumented and unwired path; `.honeybadger.conf.example` is corrected in this change to stop implying it works.
- **[One-time rebuild for existing users]** → The fixed guard rebuilds stale images on the next `USE_DOCKER_CONVERTER=true` audit. Mitigation: the new image builds in a fraction of the old one's time.
- **[Upstream pin goes stale]** → Same trade-off already accepted for the bundled Python script (archived `design.md:51`). Mitigation: the commit is recorded in the `Dockerfile` next to the repository URL.
- **[bookworm reaches EOL]** → A future change bumps the tag. Pinning makes that an explicit decision instead of a silent drift.

## Verification

The JSON output must be unchanged. Compare the old and new images against a committed sample report:

```
docker run --rm -v $PWD/lynis.dat:/data/lynis-report.dat:ro <image> | jq -S . > new.json
diff <(jq -S . old.json) new.json     # expect no differences
```

`lynis.dat` served as the fixture during this change, but it is listed in `.gitignore` and is therefore
not in the repository. Reproducing the comparison requires a local Lynis report — either a copy of
`/var/log/lynis-report.dat` from a previous audit, or a fresh `lynis audit system` run.
