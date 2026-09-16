## ADDED Requirements

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
