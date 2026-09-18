## Context

`2026-09-16-reliable-hostname-resolution` replaced one call to `hostname(1)`
and wrote a test to stop it returning. Both were scoped to `RUNME.sh`, and a
second call in `lib/_library` survived both. The interesting question is not
how to fix the line - the replacement is one identifier - but why the guard did
not see it, and what the guard has to cover so that a third occurrence cannot
repeat this.

## The guard's original scope, and why it was wrong

The previous change carried two guards, and scoping them alike was the mistake.

The `local x=$(cmd)` guard is scoped to `RUNME.sh` for a real reason, recorded
in that change's Non-goals: `lib/_library` has occurrences where a command may
legitimately produce nothing and the masked status is the intent. Widening that
one would report working code.

The `hostname(1)` guard has no such exception. There is no deliberate use of
`hostname(1)` anywhere in this repository - the whole point of the change was
that the tool may not exist. It was scoped to `RUNME.sh` by proximity to the
other guard rather than by argument, and that is exactly the file the surviving
call was not in.

So: the `local` guard stays where it is, and the `hostname(1)` guard widens to
every shell source the audit ships - `RUNME.sh`, `lib/_library` and `lib/*.sh`.

## What the widened guard matches

Two shapes, because the old pattern would have missed the cheapest way to
reintroduce this:

    hostname -s          the flags the tool was called with here
    hostname -f
    $(hostname)          no flags at all; `uname -n` already returns the
    `hostname`           short name on most hosts, so this "works" until it
                         meets a host where the package is absent

Full-line comments are stripped before matching. `lib/_library` documents what
`hostname -s` used to do, in prose, next to the function that replaced it -
that sentence is the guard working as intended, not an offender. Only lines
whose first non-blank character is `#` are dropped, so a call with a trailing
comment is still caught.

`tests/` is not scanned. A test that proves the audit runs without the tool has
to be able to stub it.

## Why submission stops when no hostname resolves

`RUNME.sh` already exits rather than write `output--<user>-<date>`. The same
argument applies one step later and slightly harder: an archive whose name has
a hole in it is at least visible on the operator's disk, whereas a submission
with an empty `X-Hostname` is filed on the server under a machine that does not
exist, and the client prints `Submission complete!`.

The check is explicit rather than left to the shell because the submit path has
no errexit to lean on - `set -e` is set inside `audit()`, not at the top of
`RUNME.sh`. A failing command substitution here is simply discarded by the next
statement, which is how the second occurrence of this defect stayed as quiet as
the first one did under `local`.

`submit_tar_file()` therefore returns 1 with a message naming the sources it
tried, matching the wording `RUNME.sh` uses for the same condition. Callers
already treat a non-zero return as a failed submission, so nothing else
changes.

This is reachable only when `uname -n`, `$HOSTNAME` and `/etc/hostname` all
fail. A host in that state cannot name its audit output either, so in practice
the run has already stopped earlier; the check is here because
`submit_tar_file()` is also callable on its own against an archive from a
previous run.

## Why the submission suite could not have caught this

`install_curl_stub()` builds a PATH holding only stubbed tools, which is what
makes "the tool is not installed" testable at all. It then linked the real
`hostname` into it, alongside `whoami` and `tar`, because the code under test
called it. The suite thereby guaranteed the one condition the defect needs
never occurs.

The header assertion was the second half of the blind spot:

    assert_contains "$args" "X-Hostname: " "the hostname is sent"

The trailing space is satisfied by an empty value, so the exact failure mode
this bug produces on a host with a broken `hostname(1)` would have passed.
Tests now assert the resolved name, with `HB_HOSTNAME_FILE` and `$HOSTNAME`
driving the chain to a known value so the assertion does not depend on the
machine running the suite.

## Alternatives considered

**Resolve once in `RUNME.sh` and pass the name down.** Fewer resolutions, but
it makes `submit_tar_file()` depend on a caller having set something, and the
function is reachable directly through the `submit` entry point. The resolver
is three shell builtins and at most one `uname`; calling it twice costs
nothing.

**Default to `unknown` instead of failing.** It puts a plausible-looking name
on a real machine's evidence, which is worse than a submission that did not
arrive: `unknown` is indistinguishable from a host genuinely named that, and
the operator has nothing to chase.
