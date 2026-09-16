---
# honeybadger-6dkw
title: 'honeybadger: make the client configuration overridable and managed'
status: todo
type: epic
priority: normal
tags:
    - honeybadger
    - config
created_at: 2026-09-16T06:27:04Z
updated_at: 2026-09-16T06:27:04Z
---

The client cannot be pointed at a different server for a test. An environment
variable can never win, there is no way to name a config file, and the working
directory is searched first.

## How the configuration is meant to work

This is deliberate and worth stating, because it is easy to mistake for an
oversight:

    .honeybadger.conf          local to each audited machine, gitignored,
                               created from .honeybadger.conf.example
    SERVER_TOKEN               issued by the badgersbay administrator to a user
    badgersbay-tokens.age      the allowlist, agenix-encrypted in
                               technative-awsaccounts-workloads, delivered to
                               compute2 as /run/agenix/badgersbay-tokens

The client holding its own credential is the access control: without a token
badgersbay knows, anyone could upload into the compliance evidence store. The
file is hand-placed on purpose.

Nothing in this epic changes that.

## What is actually wrong

`load_server_config` (`lib/_library:1424`) sets defaults and then sources the
first config file it finds:

    SERVER_URL="${SERVER_URL:-http://localhost:7123/}"   # default
    ...
    source "$config_file"                                 # overwrites it

Because the file is sourced afterwards, an environment variable can never take
precedence. There is no `--config` argument either, and the search begins at
`./.honeybadger.conf`. So anyone whose own configuration sits in the working
directory - which is where a developer's tends to live - submits wherever that
file points, with no way to redirect a single run.

That is not hypothetical: a real archive was submitted to production while
testing the archive submission change, because the local configuration in the
working directory won over the intended test configuration.

## Acceptance criteria

1. An environment variable overrides what the config file says, so the client
   can be pointed at a local server for one run without moving any file.
2. A config file can be named explicitly, so a test run cannot pick up whatever
   happens to be in the working directory.
3. The precedence is documented, because a config file that can be silently
   overridden is its own kind of surprise.

## Out of scope

- How tokens are issued and stored. That works as designed.
- Deploying `.honeybadger.conf` to audited machines. The file is local by
  design, and the machines are personal laptops rather than servers under
  configuration management.
