## MODIFIED Requirements

### Requirement: Docker converter as configurable fallback
The system SHALL support a `USE_DOCKER_CONVERTER` configuration option that, when set to `true`, uses the Docker-based Perl converter instead of the Python script. The Docker converter SHALL produce JSON output only.

#### Scenario: Docker mode enabled via config
- **WHEN** `USE_DOCKER_CONVERTER=true` is set in `honeybadger.conf`
- **AND** the user runs `./RUNME.sh audit`
- **THEN** the system SHALL use the Docker-based converter
- **AND** the system SHALL check for `docker` as a dependency
- **AND** the resulting `lynis-report.json` SHALL be byte-equivalent to the output of the Python converter for the same input, after key-order normalisation

#### Scenario: Docker mode disabled (default)
- **WHEN** `USE_DOCKER_CONVERTER` is not set or set to `false`
- **AND** the user runs `./RUNME.sh audit`
- **THEN** the system SHALL NOT require Docker
- **AND** the system SHALL NOT check for `docker` as a dependency

### Requirement: Config file documents converter option
The `.honeybadger.conf.example` file SHALL include the `USE_DOCKER_CONVERTER` option with a default value of `false` and a description that accurately reflects the Docker converter's capabilities.

#### Scenario: Example config contains converter option
- **WHEN** a user reads `.honeybadger.conf.example`
- **THEN** the file SHALL contain `USE_DOCKER_CONVERTER=false` with a comment explaining its purpose
- **AND** the comment SHALL NOT claim that the Docker converter provides HTML, PDF or Excel output

## ADDED Requirements

### Requirement: Docker image contains only JSON-path dependencies
The Docker image SHALL install only the packages required by the converter's JSON output path.

#### Scenario: Image omits unreachable format tooling
- **WHEN** the `Dockerfile` is inspected
- **THEN** it SHALL NOT install `wkhtmltopdf`, `texlive-latex-base`, `texlive-latex-recommended` or `pandoc`
- **AND** it SHALL NOT install the X11 and font libraries that existed solely to satisfy `wkhtmltopdf`
- **AND** it SHALL NOT install `cpanminus` or the `Excel::Writer::XLSX` CPAN module
- **AND** it SHALL install `libjson-perl`

#### Scenario: JSON conversion still succeeds
- **WHEN** the slimmed image is run against a Lynis `.dat` report
- **THEN** it SHALL emit valid JSON on stdout
- **AND** the output SHALL match the output of the previous image for the same input

### Requirement: Reproducible image build
The Docker image build SHALL pin both its base image and the converter source.

#### Scenario: Base image is pinned
- **WHEN** the `Dockerfile` is inspected
- **THEN** the `FROM` instruction SHALL reference a specific Debian release tag
- **AND** it SHALL NOT use the floating `debian:latest` tag

#### Scenario: Converter is pinned to a commit
- **WHEN** the `Dockerfile` is inspected
- **THEN** it SHALL fetch `lynis-report-converter` at a specific commit SHA
- **AND** it SHALL NOT download a branch archive such as `master.zip`
- **AND** the commit SHA SHALL appear in the `Dockerfile` alongside the repository URL

### Requirement: Image builds on both amd64 and arm64
The Docker image SHALL build successfully on `linux/amd64` and `linux/arm64` without architecture-specific instructions.

#### Scenario: Build on arm64
- **WHEN** the image is built on an `arm64` host
- **THEN** the build SHALL succeed
- **AND** the resulting image SHALL convert a Lynis report to JSON

#### Scenario: No silent architecture failures
- **WHEN** the `Dockerfile` is inspected
- **THEN** it SHALL NOT download architecture-specific `.deb` packages
- **AND** it SHALL NOT contain an instruction whose failure is absorbed by a following `||` operator

### Requirement: Stale image is rebuilt when the Dockerfile changes
When `USE_DOCKER_CONVERTER=true`, the audit SHALL rebuild the converter image if the `Dockerfile`'s content differs from the content the existing image was built from.

#### Scenario: Dockerfile modified after image was built
- **WHEN** the user edits the `Dockerfile`
- **AND** runs `./RUNME.sh audit` with `USE_DOCKER_CONVERTER=true`
- **THEN** the system SHALL rebuild the image before converting

#### Scenario: Dockerfile unchanged since image was built
- **WHEN** the `Dockerfile` has not been modified since the image was built
- **AND** the user runs `./RUNME.sh audit` with `USE_DOCKER_CONVERTER=true`
- **THEN** the system SHALL reuse the cached image without rebuilding

#### Scenario: Dockerfile mtime changes without a content change
- **WHEN** the `Dockerfile`'s modification time changes but its content does not, as after a fresh clone
- **AND** the user runs `./RUNME.sh audit` with `USE_DOCKER_CONVERTER=true`
- **THEN** the system SHALL reuse the cached image without rebuilding

#### Scenario: Image predates staleness tracking
- **WHEN** an image exists that was built before staleness tracking was added
- **AND** the user runs `./RUNME.sh audit` with `USE_DOCKER_CONVERTER=true`
- **THEN** the system SHALL rebuild the image

#### Scenario: Staleness is not measured against the output directory
- **WHEN** the rebuild condition in `RUNME.sh` is inspected
- **THEN** it SHALL NOT compare the `Dockerfile` timestamp against the audit output directory
