---
# honeybadger-4t57
title: 'Arch: install instructions must name the python package, not python3'
status: todo
type: task
priority: low
created_at: 2026-09-16T11:28:24Z
updated_at: 2026-09-16T11:28:24Z
---

Recorded while fixing honeybadger-y9ul, where it was noted as unrelated to that
bug.

On Arch the package is `python`, not `python3`. `pacman -S python3` fails
outright, so any install instruction naming `python3` as a package is wrong.

## Current state

`README.md` lists **python3** among the required dependencies, which is correct
as written: it names the *command*, and Arch's `python` package does provide
`/usr/bin/python3`. `checkdeps "python3"` in `RUNME.sh` checks for that command
and is also correct.

A search of the repository found no `pacman -S python3` instruction, so there
is nothing broken today.

## Why this is still worth a bean

The distinction is easy to lose the next time someone writes per-distribution
install instructions. `README.md` already carries a `sudo pacman -S lynis`
block, and a python one added beside it would be wrong.

## Task

- [ ] Add a per-distribution install block for python to `README.md`, naming
      `sudo pacman -S python` on Arch, alongside the existing Lynis block
- [ ] Confirm no other document introduces `pacman -S python3`
