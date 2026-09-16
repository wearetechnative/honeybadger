## Why

The client cannot be pointed at a different server for a single run.

`load_server_config` sets defaults and then sources the first config file it
finds:

    SERVER_ENABLED="${SERVER_ENABLED:-false}"
    SERVER_URL="${SERVER_URL:-http://localhost:7123/}"
    ...
    source "$config_file"

Because the file is sourced afterwards, an environment variable can never take
precedence. There is no way to name a config file either, and the search begins
at `./.honeybadger.conf` - which is where a user's own configuration tends to
live.

This is not only inconvenient. `DRY_RUN` is a safety control, and it cannot be
switched on from the environment when the config file has it off:

    $ DRY_RUN=true ./RUNME.sh submit <archive>
    Loading configuration from: ./.honeybadger.conf
    Submitting tar file (attempt 1/3)...
    ✓ Successfully submitted

A real archive was submitted while attempting a dry run, twice, while testing
other changes.

## What Changes

- **Environment, then file, then built-in default.** A setting present in the
  environment survives the config file. A setting absent from the environment
  takes the file's value, and only what neither supplies falls back to a
  built-in default.
- **`--config <file>`** names a configuration file and skips the search.
- **`HONEYBADGER_CONFIG`** does the same from the environment, for callers that
  cannot pass arguments.
- The loader reports which file it used and says when a setting came from the
  environment rather than the file, so a run that picked up something
  unexpected shows it in its own output.

## Capabilities

### New Capabilities
- `server-configuration`: where the client's server settings come from and
  which source wins

## Impact

- A configuration file can now be overridden from the environment, which is a
  change in behaviour rather than a fix. It is announced in the output for
  exactly that reason.
- No change to the file format, the search order, or how tokens are issued.

## Non-goals

- Deploying `.honeybadger.conf` to audited machines. The file is local by
  design: the user holds a token issued by the badgersbay administrator, and
  the allowlist lives in `badgersbay-tokens.age`. Nothing here changes that.
