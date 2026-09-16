# server-configuration Specification

## Purpose
This specification defines where the Honeybadger client's server settings come
from and which source wins. The configuration file is local to each audited
machine and holds the token the badgersbay administrator issued, so it is not
deployed centrally - but a single run has to be redirectable without editing it,
and `DRY_RUN` in particular has to be switchable from the environment.

## Requirements

### Requirement: Setting precedence

The client SHALL resolve each server setting from the environment first, then
the configuration file, then a built-in default.

#### Scenario: Environment wins over the file
- **WHEN** `SERVER_URL` is set in the environment and also in the config file
- **THEN** the environment value SHALL be used

#### Scenario: File supplies what the environment does not
- **WHEN** `SERVER_URL` is absent from the environment and present in the file
- **THEN** the file value SHALL be used

#### Scenario: Default supplies what neither does
- **WHEN** a setting appears in neither the environment nor the file
- **THEN** the built-in default SHALL be used

#### Scenario: An empty environment value is a value
- **WHEN** a setting is exported as an empty string
- **THEN** it SHALL be treated as supplied, and SHALL NOT be replaced by the
  file value or by a default

#### Scenario: Dry run can be switched on from the environment
- **WHEN** the config file sets `DRY_RUN=false` and the environment sets
  `DRY_RUN=true`
- **THEN** the run SHALL be a dry run

### Requirement: Naming a configuration file

The client SHALL accept an explicit configuration file and SHALL then skip the
search order entirely.

#### Scenario: Named on the command line
- **WHEN** `submit` is given `--config <file>`
- **THEN** that file SHALL be loaded and no other location SHALL be consulted

#### Scenario: Named in the environment
- **WHEN** `HONEYBADGER_CONFIG` names a file
- **THEN** that file SHALL be loaded and no other location SHALL be consulted

#### Scenario: Command line beats the environment
- **WHEN** both `--config` and `HONEYBADGER_CONFIG` are given
- **THEN** the command line file SHALL be used

#### Scenario: Named file is missing
- **WHEN** a named configuration file does not exist
- **THEN** the client SHALL fail and name the path, rather than falling back to
  the search order

### Requirement: Report where the configuration came from

The client SHALL say which file it loaded and which settings the environment
supplied, so a run that picked up something unexpected shows it in its own
output.

#### Scenario: File reported
- **WHEN** a configuration file is loaded
- **THEN** its path SHALL be reported

#### Scenario: Environment overrides reported
- **WHEN** the environment supplied one or more settings
- **THEN** those setting names SHALL be reported as coming from the environment

#### Scenario: No file found
- **WHEN** no configuration file is found
- **THEN** the client SHALL say so and report the settings it will use

### Requirement: Where a configuration file is looked for

The client SHALL look for a configuration file in a fixed order and use the
first one it finds, so an operator can tell which file a run will pick up
without reading the source.

#### Scenario: Search order
- **WHEN** no configuration file is named explicitly
- **THEN** the client SHALL check, in order, `./.honeybadger.conf`,
  `~/.honeybadger.conf` and `/etc/honeybadger.conf`
- **AND** SHALL use the first one that exists

#### Scenario: No file anywhere
- **WHEN** none of those exists
- **THEN** the run SHALL proceed on the environment and the built-in defaults

### Requirement: The settings and their defaults

The client SHALL read `key=value` pairs and SHALL apply a documented default for
each setting that neither the environment nor the file supplies.

#### Scenario: Recognised settings
- **WHEN** a configuration file is parsed
- **THEN** `SERVER_ENABLED`, `SERVER_URL`, `SERVER_TOKEN`, `SERVER_TIMEOUT`,
  `SERVER_RETRY_COUNT`, `DRY_RUN` and `USE_DOCKER_CONVERTER` SHALL be recognised

#### Scenario: Built-in defaults
- **WHEN** a setting is supplied by neither the environment nor the file
- **THEN** the default SHALL be `SERVER_ENABLED=false`,
  `SERVER_URL=http://localhost:7123/`, `SERVER_TOKEN` empty,
  `SERVER_TIMEOUT=30`, `SERVER_RETRY_COUNT=3`, `DRY_RUN=false` and
  `USE_DOCKER_CONVERTER=false`

#### Scenario: Submission is off until it is turned on
- **WHEN** no configuration has been made
- **THEN** `SERVER_ENABLED` SHALL default to `false`, so a client does not
  report anywhere until someone says where
