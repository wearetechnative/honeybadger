## 1. Linux serial chain

- [ ] 1.1 Read `/sys/class/dmi/id/product_serial` as the first source
- [ ] 1.2 Fall back to `/sys/class/dmi/id/board_serial` when the first is
      empty or a placeholder
- [ ] 1.3 Fall back to `dmidecode -s system-serial-number` when present
- [ ] 1.4 Fall back to `nix run nixpkgs#dmidecode --extra-experimental-features
      "nix-command flakes" -- -s system-serial-number` on NixOS
- [ ] 1.5 Try each step only when the previous produced nothing usable
- [ ] 1.6 Do not add `dmidecode` to `checkdeps` - the dependency is the serial,
      not the tool

## 2. macOS serial

- [ ] 2.1 Read `IOPlatformSerialNumber` via
      `ioreg -d2 -c IOPlatformExpertDevice`
- [ ] 2.2 Fall back to `system_profiler SPHardwareDataType`, parsed on the
      `Serial Number` label
- [ ] 2.3 Remove the path that produced `Mac OS X<TAB>`

## 3. Shared validation

- [ ] 3.1 One shared function decides whether a value is usable: one token, no
      whitespace, no placeholder, not all zeroes
- [ ] 3.2 Placeholder list matches the collection server: `Not available`,
      `Not available (VM or unknown hardware)`, `To Be Filled By O.E.M.`,
      `To Be Filled`, `Default string`, `Not Specified`,
      `System Serial Number`, `None`, `Unknown`
- [ ] 3.3 Never write an unusable value into `hardware-serial.txt` as though it
      were a measurement

## 4. Reporting

- [ ] 4.1 Write `could-not-read` when no source returned anything
- [ ] 4.2 Write `none-present` when a source returned a placeholder or empty
      value, which virtual machines legitimately do
- [ ] 4.3 Report the outcome at the end of the run where the operator sees it,
      naming which of the two applies
- [ ] 4.4 Include the serial and its source in `asset-inventory.txt`

## 5. Tests

- [ ] 5.1 Unit tests for the validation function over the real values found on
      compute2: `PF50L2MR`, `MP1Y69AC`, `FRANDGCPA5530200H9`, `Not available`,
      `Mac OS X<TAB>`, `00000000`, empty, absent
- [ ] 5.2 Test the Linux chain with each source stubbed in turn, asserting the
      later steps are not reached when an earlier one succeeds
- [ ] 5.3 Test the macOS parser against real `ioreg` and `system_profiler`
      output captured from a Mac
- [ ] 5.4 Test that a machine with no usable serial produces `none-present` and
      a visible message, not a silent file

## 6. Verify on real machines

- [ ] 6.1 NixOS without `dmidecode` in PATH - the case that produced
      `Not available` for technative-casper and nixos-pankhurip
- [ ] 6.2 Ubuntu or Debian
- [ ] 6.3 Arch
- [ ] 6.4 macOS - confirm the value matches the serial in the About This Mac
      panel
- [ ] 6.5 A virtual machine - confirm `none-present` rather than a fabricated
      value

## 7. Docs

- [ ] 7.1 `README.md`: name the sources per platform and what the two
      not-found values mean
- [ ] 7.2 `CHANGELOG.md` under NEXT VERSION
