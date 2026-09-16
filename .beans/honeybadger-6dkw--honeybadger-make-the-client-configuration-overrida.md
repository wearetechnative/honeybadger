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

The client's server configuration cannot be overridden, cannot be pointed
somewhere else for a test, and is not managed anywhere. Every audited machine
carries a hand-placed `.honeybadger.conf` holding the production URL and a
bearer token.

## What is wrong

`load_server_config` (`lib/_library:1424`) sets defaults and then sources the
first config file it finds:

    SERVER_URL="${SERVER_URL:-http://localhost:7123/}"   # default
    ...
    source "$config_file"                                 # overwrites it

Because the file is sourced afterwards, an environment variable can never win.
There is no `--config` argument either. The only way to submit anywhere other
than what the file says is to move the file out of the way.

The search order compounds it:

    ./.honeybadger.conf        <- the repository working directory
    $HOME/.honeybadger.conf
    /etc/honeybadger.conf

A checkout of this repository contains a `.honeybadger.conf` pointing at
production, and the current directory is searched first. Anyone running the
audit from the repository submits to production, whatever they intended.

That is not hypothetical: it happened while testing the archive submission
change. A real archive was submitted to production because the production
config in the working directory won over the test configuration.

## Why it is not just a testing annoyance

Nothing manages this file. Searching `technative-awsaccounts-workloads` for
`honeybadger.conf`, `SERVER_URL` and `SERVER_TOKEN` returns nothing: the server
side is deployed through the elastinix module and agenix, the client side is
placed by hand on each machine.

So the bearer token that grants write access to the compliance evidence store
lives in an unmanaged file on eleven laptops, with no record of which token is
where, and no way to rotate one without visiting each machine.

## Acceptance criteria

1. An environment variable overrides what the config file says, so the client
   can be pointed at a local server without moving any file.
2. A config file can be named explicitly, so a test run cannot accidentally
   pick up the one in the working directory.
3. Running the audit from a checkout of this repository does not silently
   submit to production.
4. The client configuration on an audited machine is deployed rather than
   hand-placed, with the token delivered as a secret.
5. Rotating a token does not require logging into each machine.

## Out of scope

The server side. Compute2 already receives its configuration, tokens and
password as agenix secrets through the elastinix module; this epic is about the
other end of the connection.
