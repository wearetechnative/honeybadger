## Decision: the kernel is the primary source, not a tool

`/sys/class/dmi/id/product_serial` is mode 0400 and contains exactly the system
serial:

    $ ls -l /sys/class/dmi/id/product_serial
    -r-------- 1 root root 4096 /sys/class/dmi/id/product_serial
    $ sudo cat /sys/class/dmi/id/product_serial
    PF50L2MR

It is a kernel sysfs interface, so it behaves the same on NixOS, Ubuntu, Debian
and Arch - there is no package to install and no distribution-specific path.
The audit already requires root, so it can read it directly.

`dmidecode` reads the same SMBIOS table through `/sys/firmware/dmi/tables/DMI`.
Requiring the tool to reach data the kernel already parsed adds a dependency
for nothing.

### Why not add dmidecode to checkdeps

Adding it to `checkdeps` (`RUNME.sh:33`) would abort the audit on machines where
sysfs works perfectly, which is most of them. The dependency is the serial, not
the tool that fetches it. Checking for a tool that is usually unnecessary turns
a soft problem into a hard failure.

### Why not reach for nix run first

`nix run nixpkgs#dmidecode` works and is a reasonable last resort on NixOS, but
it needs flakes enabled, needs the network on first use, and is slow. With
sysfs first it should never be reached. It stays in the chain because a machine
without SMBIOS sysfs but with working nix is possible, and the cost of keeping
the branch is one `elif`.

## The chain

    1. /sys/class/dmi/id/product_serial     root, no tool, no network
    2. /sys/class/dmi/id/board_serial       some vendors fill only this one
    3. dmidecode -s system-serial-number    if the tool happens to be present
    4. nix run nixpkgs#dmidecode            NixOS last resort, needs network

Each step is tried only when the previous produced nothing usable, so a machine
with a working sysfs never pays for the rest.

## Decision: macOS reads ioreg, not system_profiler

The current macOS path writes `Mac OS X<TAB>` - a fragment of unrelated output,
almost certainly from matching the wrong line of `system_profiler`. That output
is a formatted human report, its labels have changed across releases, and
"Serial Number" appears in more than one section.

`ioreg` exposes the value as a property rather than as prose:

    ioreg -d2 -c IOPlatformExpertDevice \
      | awk -F'"' '/IOPlatformSerialNumber/{print $(NF-1)}'

`system_profiler SPHardwareDataType` stays as the fallback, parsed on the
`Serial Number` label, because it is available even in stripped environments
where `ioreg` behaves oddly.

## Decision: validate before writing, and say so when there is none

Every platform runs the same check before the value is written. A usable serial
is one token: non-empty, no whitespace, not a known placeholder
(`Not available`, `To Be Filled By O.E.M.`, `Default string`, `System Serial
Number`, `None`, all zeroes).

This is the rule the collection server applies when matching, so applying it at
the source means the client and the server agree on what counts. Writing a
value the server will reject anyway helps nobody, and writing `Mac OS X` is
worse than writing nothing: it looks like data.

When nothing usable is found the audit writes the file with a single explicit
token and reports the reason where the operator sees it. Two reasons, because
they need different responses:

    could-not-read   nothing in the chain returned a value - a machine or
                     packaging problem worth chasing
    none-present     the hardware reports an empty or placeholder serial, which
                     virtual machines legitimately do

The first is fixable. The second is a fact about the machine, and an asset that
genuinely has no serial needs a different key in the register rather than a
repair.

## Consequence for the collection server

badgersbay normalises and rejects placeholders on its side, and records
`no_serial` for a submission it cannot key. That behaviour does not change.
What changes is how often it fires: two of the three Linux systems currently
landing there have a readable serial that this audit was simply not looking at.
