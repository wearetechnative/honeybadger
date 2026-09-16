## 1. Collection

- [x] 1.1 `lib/check-os-status.sh`: remove the `neofetch.json`, `neofetch.txt`
      and `fastfetch.txt` branches from the format selection
- [x] 1.2 Missing `fastfetch.json` exits with an error naming the file and the
      command that produces it
- [x] 1.3 Remove the legacy note emitted when live kernel data is unavailable
      because of an old format
- [x] 1.4 Drop `FETCH_FORMAT` and the text-parsing branches it selected: with
      one format the distinction has nothing left to distinguish

## 2. The path the client actually runs

`lib/check-os-status.sh` is a standalone duplicate that `RUNME.sh` never calls.
The live path is `extract_os_info()` and `check_os_status()` in `lib/_library`,
which carried the same fallback chain - so fixing only the script would have
left the behaviour unchanged.

- [x] 2.1 Add `require_fastfetch_json()` to `lib/_library`, naming the file, the
      command that produces it, and any retired format found beside it
- [x] 2.2 `extract_os_info()`: read `fastfetch.json` only
- [x] 2.3 `check_os_status()`: refuse before fetching or writing anything
- [x] 2.4 `RUNME.sh check-output`: refuse before the cache fetch, so a directory
      in a retired format is left exactly as it was found

## 3. The rest of the client

With a directory lacking `fastfetch.json` refused at the door, every remaining
legacy branch is unreachable. Left in place they would be dead code that still
reads as support.

- [x] 3.1 `generate_asset_inventory()`: hardware info from `fastfetch.json` only
- [x] 3.2 Nix detection: `fastfetch.json` only
- [x] 3.3 `is_nixos()` fallback: `fastfetch.json` only
- [x] 3.4 `generate_xlsx_asset_row_report()`: model from `fastfetch.json` only
- [x] 3.5 `hb_audit_username()`: `fastfetch.json`, then the directory name

## 4. Specifications

- [x] 4.1 `system-information-collection`: remove the backward-compatibility
      requirement (delta already written)
- [x] 4.2 `check-os-status`: remove the requirement carrying the fallback chain
      and the legacy degradation scenario, and restate both without them
- [x] 4.3 `audit-identity-resolution`: remove the "Older archives still read
      back" scenario, which this change makes unreachable

## 5. Tests

- [x] 5.1 Add `tests/test_fastfetch_only.sh`
- [x] 5.2 Cover the gate: accepted, refused, and the wording of the error
- [x] 5.3 Cover each retired format being refused rather than used
- [x] 5.4 Cover extraction reading `fastfetch.json` and ignoring the others
- [x] 5.5 Cover `check_os_status` refusing, and writing nothing into the
      directory it refused
- [x] 5.6 Guard test: no retired filename is read anywhere in the client
- [x] 5.7 Replace `basename` in the identity helpers, which the new path reached
      under the suite's restricted PATH

## 6. Verify

- [x] 6.1 `check-output` on a current output directory is unchanged
- [x] 6.2 `check-output` on a directory containing only `neofetch.json` fails
      with the new error
- [x] 6.3 Every generated artifact byte-identical before and after, against the
      real `output-lobos-wtoorren-15-09-2026`
- [x] 6.4 `./tests/run-tests.sh` passes in full
- [x] 6.5 `shellcheck` and `bash -n` on the changed files
