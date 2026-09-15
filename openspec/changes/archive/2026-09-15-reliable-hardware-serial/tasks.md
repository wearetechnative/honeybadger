## 1. Linux serial chain

- [x] 1.1 Read `/sys/class/dmi/id/product_serial` as the first source
- [x] 1.2 Fall back to `/sys/class/dmi/id/board_serial` when the first is
      empty or a placeholder
- [x] 1.3 Fall back to `dmidecode -s system-serial-number` when present
- [x] 1.4 Fall back to `nix run nixpkgs#dmidecode --extra-experimental-features
      "nix-command flakes" -- -s system-serial-number` on NixOS
- [x] 1.5 Try each step only when the previous produced nothing usable
- [x] 1.6 Do not add `dmidecode` to `checkdeps` - the dependency is the serial,
      not the tool

## 2. macOS serial

- [x] 2.1 Read `IOPlatformSerialNumber` via
      `ioreg -d2 -c IOPlatformExpertDevice`
- [x] 2.2 Fall back to `system_profiler SPHardwareDataType`, parsed on the
      `Serial Number` label
- [x] 2.3 Remove the path that produced `Mac OS X<TAB>`

## 3. Shared validation

- [x] 3.1 One shared function decides whether a value is usable: one token, no
      whitespace, no placeholder, not all zeroes
- [x] 3.2 Placeholder list matches the collection server: `Not available`,
      `Not available (VM or unknown hardware)`, `To Be Filled By O.E.M.`,
      `To Be Filled`, `Default string`, `Not Specified`,
      `System Serial Number`, `None`, `Unknown`
- [x] 3.3 Never write an unusable value into `hardware-serial.txt` as though it
      were a measurement

## 4. Reporting

- [x] 4.1 Write `could-not-read` when no source returned anything
- [x] 4.2 Write `none-present` when a source returned a placeholder or empty
      value, which virtual machines legitimately do
- [x] 4.3 Report the outcome at the end of the run where the operator sees it,
      naming which of the two applies
- [x] 4.4 Include the serial and its source in `asset-inventory.txt`

## 5. Tests

- [x] 5.1 Unit tests for the validation function over the real values found on
      compute2: `PF50L2MR`, `MP1Y69AC`, `FRANDGCPA5530200H9`, `Not available`,
      `Mac OS X<TAB>`, `00000000`, empty, absent
- [x] 5.2 Test the Linux chain with each source stubbed in turn, asserting the
      later steps are not reached when an earlier one succeeds
- [x] 5.3 Test the macOS parser against real `ioreg` and `system_profiler`
      output captured from a Mac
      - Fixtures in `tests/fixtures/` reproduce the exact output format of both
        tools, including the properties that sit next to the serial and used to
        be picked up by mistake. No Mac was reachable from the machine this was
        implemented on, so they are written to the documented format rather than
        piped from a live system - see task 6.4
- [x] 5.4 Test that a machine with no usable serial produces `none-present` and
      a visible message, not a silent file

## 6. Verify on real machines

- [x] 6.1 NixOS without `dmidecode` in PATH - the case that produced
      `Not available` for technative-casper and nixos-pankhurip
- [x] 6.2 Ubuntu or Debian
- [x] 6.3 Arch
- [ ] 6.4 macOS - confirm the value matches the serial in the About This Mac
      panel
      - NOT DONE: no Mac was reachable from the machine this was implemented on.
        Tracked as a follow-up bean; the parsers are covered by unit tests and
        the whole macOS chain is exercised with both tools stubbed
- [x] 6.5 A virtual machine - confirm `none-present` rather than a fabricated
      value

## 7. Docs

- [x] 7.1 `README.md`: name the sources per platform and what the two
      not-found values mean
- [x] 7.2 `CHANGELOG.md` under NEXT VERSION
