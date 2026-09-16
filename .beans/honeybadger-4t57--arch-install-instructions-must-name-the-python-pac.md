---
# honeybadger-4t57
title: Per-distribution install instructions for the required dependencies
status: completed
type: task
priority: low
tags:
    - docs
    - arch
created_at: 2026-09-16T11:28:24Z
updated_at: 2026-09-16T12:23:10Z
---

`README.md` lists five required dependencies and then tells you how to install
exactly one of them. `#### Installing Lynis` carries four per-distribution
blocks; `fastfetch`, `jq`, `curl` and `python3` are named on the list and left
there.

That is upside down. Lynis is the easy one - it is in every archive under its
own name. `fastfetch` is the hard one, and it is the one with no instructions.

## What the acceptance test found

Two platforms, two entirely different answers for the same required dependency:

| Platform         | fastfetch                                       |
|------------------|-------------------------------------------------|
| Arch             | in `extra`, `pacman -S fastfetch`               |
| Ubuntu 24.04     | **not in the noble archive** - needed an upstream release `.deb` |

Neither is discoverable from the README. Someone setting up an Ubuntu host hits
`<fastfetch> could not be found`, tries `apt install fastfetch`, and is stuck
with no idea that the package simply is not there.

This is knowledge that currently exists only in an agent's test log. Writing it
down is the point of this bean.

## The python note this bean started as

On Arch the package is `python`, not `python3`. `pacman -S python3` fails
outright, which is what prompted the original bean.

Nothing is broken today, and this was checked rather than assumed:

- `README.md:15` names **python3** as a dependency. That is the *command*, and
  Arch's `python` package provides `/usr/bin/python3`. Correct as written.
- `RUNME.sh:98` does `checkdeps "python3"`, and `checkdeps` is `command -v $1` -
  it tests for the command, not a package. Succeeds on Arch.
- No `pacman -S python3` appears anywhere in the repository.

So it is one footnote inside the fastfetch work, not a task of its own. It only
becomes wrong the moment someone writes a python install block beside the Lynis
one and reaches for the obvious name.

## Task

- [ ] Add per-distribution install blocks for `fastfetch`, beside the existing
      Lynis section: Arch `pacman -S fastfetch`, Ubuntu/Debian the upstream
      `.deb` from the fastfetch releases, Fedora, macOS `brew`
- [ ] Confirm the Ubuntu route before publishing it. The acceptance run resolved
      it with an upstream release `.deb`, but the exact package and version were
      not recorded - do not copy a URL out of this bean, check it
- [ ] Cover `jq`, `curl` and `python3` in the same section, naming the Arch
      package as `python`
- [ ] State plainly that fastfetch is absent from the Ubuntu 24.04 archive, so
      the reader knows why `apt install fastfetch` fails rather than assuming
      they mistyped

## Priority

Low, and it should stay low. Nothing is broken; this is a hole in the
documentation that costs whoever next onboards a non-Arch Linux host an
afternoon. Fold it in the next time `README.md` is open for another reason
rather than scheduling it on its own.


## Done

`README.md` now carries `#### Installing fastfetch` and `#### Installing the
remaining dependencies` beside the existing Lynis section, and the dependency
list points at the first of them.

Every claim was verified against the distributions' own package APIs on
2026-09-16 rather than taken from the acceptance log:

| Source                | fastfetch                                        |
|-----------------------|--------------------------------------------------|
| Arch `extra`          | 2.68.1                                           |
| Debian trixie         | 2.40.4  (sid/forky 2.67.1)                       |
| Ubuntu noble 24.04    | **not published** - confirmed absent on Launchpad|
| Ubuntu plucky 25.04   | 2.38.0, and every release after it               |
| Fedora 43             | 2.68.1                                           |
| Homebrew              | 2.68.1                                           |

So the acceptance run's finding holds exactly: fastfetch entered Ubuntu at
25.04, and 24.04 LTS - the release most fleet hosts are on - has to take the
upstream `.deb`. That is now the documented route, with `-amd64`, `-aarch64`
and the `.rpm` all checked to resolve 200 through
`releases/latest/download/`.

The python note landed where it belongs: one line under the Arch block saying
the package is `python`, that `pacman -S python3` fails, and that it still
provides the `/usr/bin/python3` the audit looks for.

No code changed and no OpenSpec change was needed - `README.md` only.
