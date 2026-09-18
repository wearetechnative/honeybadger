## 1. A module the tests can reach

- [x] 1.1 Create `lib/Honeybadger.psm1` holding the logic that is not
      Windows-specific, with every function taking its inputs as parameters
- [x] 1.2 `Test-HbUsableSerial`, mirroring `is_usable_serial()` - placeholder
      list, all-zeroes, whitespace, `could-not-read` and `none-present`
- [x] 1.3 `Resolve-HbSerial`, returning value, source and status
- [x] 1.4 `ConvertTo-HbFastfetchJson`, against the same two patterns the jq
      expression in `RUNME.sh` uses
- [x] 1.5 `New-HbFinding` and `New-HbAssetInventory`, mirroring
      `_inventory_finding` and `_write_asset_inventory_json`
- [x] 1.6 `Get-HbOutputDirectoryName` and `Get-HbArchiveName`, producing the
      strings `RUNME.sh:123-124` builds
- [x] 1.7 `Get-HbConfiguration`, file then environment, reporting overrides
- [x] 1.8 `Get-HbSubmissionUri` and `Get-HbSubmissionOutcome`

## 2. fastfetch replaces neofetch

- [x] 2.1 Ship `lib/fastfetch-config-windows.jsonc` producing the same keys as
      the Linux config through modules that exist on Windows
- [x] 2.2 Run fastfetch and write `fastfetch.json` through the module's parser
- [x] 2.3 Install through winget when absent; stop with a named dependency when
      that fails
- [x] 2.4 Remove the neofetch install, invocation and `neofetch.txt`
- [x] 2.5 Take the compliance report's OS version from `fastfetch.json`

## 3. The serial reaches the archive

- [x] 3.1 Write `hardware-serial.txt` and `hardware-serial-source.txt`
- [x] 3.2 Decide usability with `Test-HbUsableSerial`, not with a literal
- [x] 3.3 Write `none-present` for a placeholder and `could-not-read` when the
      query failed
- [x] 3.4 Report the outcome at the end of the run
- [x] 3.5 Use the same determination in the compliance report

## 4. asset-inventory.json

- [x] 4.1 Build the generation 2 document with `platform` `windows`
- [x] 4.2 Map the existing BitLocker, screen lock, firewall, update and OS
      determinations onto the findings
- [x] 4.3 `hardening_score` carries a null value, `tool` `hardeningkitty` and
      the measured counts
- [x] 4.4 Serialise with enough depth that no branch becomes
      `System.Collections.Hashtable`

## 5. The tar archive

- [x] 5.1 Name the output directory `output-<host>-<user>-<dd-MM-yyyy>`
- [x] 5.2 Produce `honeybadger-<host>-<user>-<dd-MM-yyyy>.tar.gz` with `tar`
- [x] 5.3 Report clearly and keep the output directory when `tar` is absent
- [x] 5.4 Remove the `Compress-Archive` path

## 6. Submission

- [x] 6.1 Submit to `SERVER_URL/submit-tar` as `application/x-tar`
- [x] 6.2 Find the latest `.tar.gz` rather than the latest zip
- [x] 6.3 Bearer token, `X-Hostname`, `X-Username`; refuse to send an empty
      hostname
- [x] 6.4 Handle 4xx, 207 and 5xx per the capability, with backoff
- [x] 6.5 `DRY_RUN` rehearsal, and environment overriding the config file
- [x] 6.6 Print the configured URL rather than `$config.SERVER_URL`

## 7. Tests

- [x] 7.1 `tests/Honeybadger.Tests.ps1` covering the module's functions
- [x] 7.2 Pin the serial rule against the same values the bash suite uses
- [x] 7.3 Guards: no neofetch, no `Compress-Archive`, `/submit-tar` targeted
- [x] 7.4 Run the Pester file from `tests/run-tests.sh`, skipping with a
      message when `pwsh` is absent
- [x] 7.5 Verify the new tests fail against the unfixed client
- [x] 7.6 End-to-end: build an archive and submit it to a real HTTP server
- [x] 7.7 Run the full suite

## 8. Close out

- [x] 8.1 `openspec validate windows-tar-submission --strict`
- [x] 8.2 CHANGELOG entry under `## NEXT VERSION`
- [x] 8.3 Archive the change and commit
