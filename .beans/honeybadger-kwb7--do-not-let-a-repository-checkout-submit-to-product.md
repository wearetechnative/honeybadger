---
# honeybadger-kwb7
title: Do not let a repository checkout submit to production by default
status: scrapped
type: task
priority: normal
tags:
    - honeybadger
    - config
created_at: 2026-09-16T06:27:27Z
updated_at: 2026-09-16T06:32:39Z
parent: honeybadger-6dkw
---

**Scrapped: absorbed by honeybadger-s34v and honeybadger-xa2n.**

This was written believing the repository shipped a configuration pointing at
production. It does not: `.honeybadger.conf` is gitignored and untracked, and
only `.honeybadger.conf.example` is in the repository. The file in a checkout is
the developer's own.

Once an environment variable can override the file and a config file can be
named explicitly, there is a safe way to redirect a single run and this needs no
separate change.

---

`./.honeybadger.conf` is the first entry in the search order and this
repository contains one pointing at production. Anyone running the audit from
a checkout submits there.

Options, to be weighed rather than assumed:

- drop the working directory from the search order entirely and rely on
  `$HOME` and `/etc`, with `--config` for anything else
- keep it but require the file to be outside the repository
- keep it and gitignore `.honeybadger.conf`, so a checkout has none

The last is the smallest change but leaves the trap for anyone who creates the
file for convenience. Whichever is chosen, the reasoning belongs in the README:
this is the kind of default that looks harmless until it is not.
