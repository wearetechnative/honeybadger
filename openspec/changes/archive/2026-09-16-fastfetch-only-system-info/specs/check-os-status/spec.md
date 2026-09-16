## REMOVED Requirements

### Requirement: fastfetch.json recognized as input source

**Reason**: The requirement made `fastfetch.json` the *preferred* source with a
documented fallback chain to `neofetch.json`, `neofetch.txt` and
`fastfetch.txt`. The client no longer produces any of those and the collection
server accepts only `fastfetch.json`, so the fallback kept a retired shape alive
in the code that most needs one shape. Replaced by "System information source is
fastfetch.json only".

**Migration**: Output directories produced before the fastfetch migration must
be re-audited with a current client. They predate the 2026-03 audit round and
are archive material; the archives stay readable, it is only the re-analysis
that no longer accepts them.

### Requirement: Live kernel series comparison using kernel_latest

**Reason**: Its "No fastfetch.json present — graceful degradation" scenario
described the legacy path, which cannot be reached now that a directory without
`fastfetch.json` is refused. The rest of the requirement is unchanged and is
restated as "Kernel series comparison using kernel_latest".

**Migration**: None. The two reachable scenarios keep their behaviour.

## ADDED Requirements

### Requirement: System information source is fastfetch.json only

check-os-status.sh SHALL read system information from `fastfetch.json` only, and
SHALL refuse a directory that does not carry it rather than reading another
format.

#### Scenario: fastfetch.json is used when present
- **WHEN** check-os-status.sh is run against an output directory
- **AND** `fastfetch.json` is present
- **THEN** `fastfetch.json` SHALL be used as the fetch file source
- **AND** OS and kernel information SHALL be extracted using jq on the flat
  JSON structure

#### Scenario: No fastfetch.json present
- **WHEN** `fastfetch.json` is not present in the output directory
- **THEN** check-os-status.sh SHALL exit non-zero with an error naming the
  missing file and the command that produces it
- **AND** SHALL NOT read `neofetch.json`, `neofetch.txt` or `fastfetch.txt`

#### Scenario: A retired format is named as such
- **WHEN** the directory carries `neofetch.json`, `neofetch.txt` or
  `fastfetch.txt` but no `fastfetch.json`
- **THEN** the error SHALL say which retired format was found, so that a
  directory plainly holding system information is not simply called empty

#### Scenario: Nothing is written into a refused directory
- **WHEN** check-os-status.sh refuses a directory for missing system information
- **THEN** no `os-kernel-status.txt` is created in it

### Requirement: Kernel series comparison using kernel_latest

check-os-status.sh SHALL use the `kernel_latest` field from `fastfetch.json` to
determine kernel status, rather than a hardcoded kernel version database.

#### Scenario: kernel_latest present — series is upstream-maintained
- **WHEN** `fastfetch.json` contains a non-empty `kernel_latest` field
- **THEN** the kernel series SHALL be considered upstream-maintained
- **AND** the report SHALL show the upstream latest version

#### Scenario: kernel_latest absent or empty — series is upstream EOL
- **WHEN** `fastfetch.json` is present but `kernel_latest` is absent or empty
- **THEN** the kernel series SHALL be reported as "upstream EOL or status
  unknown"
- **AND** the report SHALL recommend checking kernel.org for the current status
