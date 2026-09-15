## Why

The audit writes `Not available` as a hardware serial whenever `dmidecode` is
absent, and on macOS it writes a fragment of unrelated output. Measured across
the 22 archives stored on compute2-prod, only five systems carry a usable
serial:

    FRANMDCPA750850030   lego2-pim                   usable
    PF50L2MR             lobos-wtoorren              usable
    FRANDGCPA5530200H9   Jeroen-jeroen               usable
    PF50L2ML             mathijs-p16s-mathijs        usable
    MP1Y69AC             pankhuri-... (3 archives)   usable

    Not available        technative-casper-casper    (4 archives)
    Not available        nixos-pankhurip             (4 archives)
    Not available        SammyMBPro-Sammy            (macOS)
    "Mac OS X<TAB>"      MBP-van-pim-pim             (macOS)

`RUNME.sh:171-175` is the Linux cause:

    if command -v dmidecode >/dev/null 2>&1; then
      dmidecode -s system-serial-number ... || echo "Not available" > ...
    else
      echo "Not available" > "$output/hardware-serial.txt"
    fi

This is not a privilege problem. `RUNME.sh:84` already requires root and exits
otherwise, so every audit that produced output ran as root. The tool is simply
not installed on some machines - on NixOS it is not in PATH by default, and
where it happens to sit in a user profile the serial came out fine.

The collection server now matches submissions on the hardware serial. A
submission without one is stored and reported, never lost, but the asset stays
outstanding for the round. Roughly half the fleet is in that state.

## What Changes

- **Read the serial from the kernel first.** `/sys/class/dmi/id/product_serial`
  is root-only, needs no tool, no network and no package, and is a kernel
  interface rather than a distribution feature - the same path works on NixOS,
  Ubuntu, Debian and Arch.
- **Keep `dmidecode` as a fallback**, and on NixOS fall back once more to
  `nix run nixpkgs#dmidecode` before giving up.
- **Fix macOS** by reading `IOPlatformSerialNumber` from `ioreg`, with
  `system_profiler` as the fallback.
- **Validate before writing.** A serial is one token with no whitespace and no
  placeholder value. Anything else is not written as if it were data.
- **Report the outcome.** When no usable serial can be determined the audit
  says so where the operator will see it, and says which of the two reasons
  applies: nothing could read it, or the hardware genuinely has none.

## Capabilities

### New Capabilities
- `hardware-serial-collection`: how the audit determines the hardware serial on
  each supported platform, what counts as usable, and what it reports when
  there is none

## Impact

- `technative-casper` and `nixos-pankhurip` stop submitting without a serial,
  which removes them from the collection server's unmatched list.
- macOS submissions carry a real serial instead of a misleading string.
- No new dependency on Linux: the primary path uses only the kernel.
- Behaviour change for virtual machines: they often have no serial at all, and
  the audit now says so plainly instead of writing `Not available` as though it
  were a measurement.

## Non-goals

- Windows. `AUDIT.ps1` already reads `Win32_BIOS.SerialNumber` correctly; it
  only fails to write the value to a file, which is bean honeybadger-k80g.
- Changing what the collection server does with a missing serial. It already
  stores the submission and reports `no_serial`.
