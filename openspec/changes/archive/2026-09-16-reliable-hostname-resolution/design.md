# Design

## The defect, precisely

    local hostname=$(hostname -s)

Two separate problems sit on one line.

**The command is not universal.** `hostname(1)` ships in `inetutils` on Arch and
is not part of the base install. It is present on Debian, Ubuntu and macOS, so
the gap only shows on the distributions nobody tested on.

**The status is thrown away.** `local` is a builtin with its own exit status,
and in `local x=$(cmd)` that status is the builtin's - 0, always. `set -e` sees
success. The substitution's failure is unobservable. The same is true of
`declare`, `export` and `readonly`.

The second problem is the one worth fixing carefully, because it is what turned
a missing package into a silently wrong archive name.

## Source chain

| Order | Source          | Why it is where it is                                     |
|-------|-----------------|-----------------------------------------------------------|
| 1     | `uname -n`      | coreutils - installed on every distribution and on macOS  |
| 2     | `$HOSTNAME`     | set by bash itself; no process, works if coreutils is odd |
| 3     | `/etc/hostname` | the file the other two are usually derived from           |

`uname -n` leads rather than `$HOSTNAME` because it asks the kernel. `$HOSTNAME`
is captured by bash at startup and a login shell that inherited a stale value
from its parent keeps it; `uname -n` cannot be stale. `$HOSTNAME` is second
rather than absent because it is the one source that needs no executable at all.

`/etc/hostname` is last because it is configuration rather than state: it is
what the host will be called after the next boot, which is not always what it is
called now.

Each source is consulted only when the previous produced nothing usable. This
mirrors `hb_collect_serial_linux()`, which the tests and the reader already
know.

## Shortening

`hostname -s` cut at the first dot. `${candidate%%.*}` does exactly that, so
`web01.example.com` becomes `web01` as before, and a name with no dot is
unchanged. No process is spawned.

## What counts as a usable hostname

The value becomes a path component and part of a tar archive's name, so the
check is about whether it can name a file, not about DNS validity:

- non-empty after shortening
- no whitespace and no control characters (`uname -n` on a misconfigured host
  has been seen to return an empty line plus a newline)
- no `/` - a slash would silently change where the output directory is created

A candidate that fails moves to the next source rather than aborting, because
a bad `/etc/hostname` should not be able to stop a run that `uname -n` could
have answered.

`localhost` is accepted. It is a poor name for a fleet asset but it is what the
machine is actually called, and substituting something else would be inventing
data - the same reasoning `is_usable_serial()` applies in the opposite
direction.

## Failing loudly

When no source yields a usable value, `hb_resolve_short_hostname()` returns 1
and `RUNME.sh` stops:

    local hostname
    if ! hostname=$(hb_resolve_short_hostname); then
      echo "ERROR: could not determine this machine's hostname" >&2
      echo "  Tried: uname -n, \$HOSTNAME, /etc/hostname" >&2
      exit 1
    fi

Assignment and test are separate statements, which is the whole point. Naming
the three sources in the error is what turns "it broke" into "your
/etc/hostname is empty and uname is not on PATH".

Stopping is the right response rather than substituting `unknown`. The name
identifies the machine in a fleet; an archive that claims to be from `unknown`
is worse than an archive that was never produced, because it is filed and
counted.

## Testability

The resolver lives in `lib/_library` so the suite can reach it, and takes its
inputs from overridable globals in the established `HB_*` style:

    HB_HOSTNAME_FILE   default /etc/hostname

`uname` is exercised through `PATH` stubs, as `link_real_tools()` and
`stub_tool()` already allow; `$HOSTNAME` is an ordinary variable a test can set.
That covers every branch without touching the machine running the tests, which
is the only way to test "uname is missing" on a host that has it.

## The guard test

Fixing one occurrence does not stop the next. `tests/test_hostname_resolution.sh`
greps `RUNME.sh` for `local <name>=$(`; any match fails with the line number.

Scoped to `RUNME.sh` deliberately. The ~80 occurrences in `lib/_library` were
read during this change: each pairs a command that may legitimately produce
nothing (`jq` on an absent key, `date` on an unparseable string, `grep` on a
line that is not there) with `2>/dev/null` and a fallback value. There the
masked status is the intent. Failing the suite on them would produce a large
diff that changes no behaviour and would train the next reader to disable the
check.

## Alternatives considered

**`hostnamectl --static`.** systemd-only. Excludes macOS outright and adds a
dependency where coreutils already answers.

**Keep `hostname -s`, add a `checkdeps "hostname"`.** Turns a silent wrong name
into a hard stop, which is better, but it makes every Arch operator install
`inetutils` to learn their machine's own name. The information is already
available without it.

**`${HOSTNAME%%.*}` alone.** One line, no process - but empty in a shell that
did not set it, including any non-interactive `sh`-invoked path, and stale
where it was inherited. Kept as the second source for its zero-dependency
property, not as the first.
