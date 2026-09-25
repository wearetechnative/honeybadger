## Why

The xlsx asset row report leaves column `A` (Asset) and `N` (proof_file) to the operator, because
the audit cannot know the asset ID: that lives in badgersbay's asset register. But the operator does
not work from a local audit. They download the archive from badgersbay and run `check-output` on
it, and badgersbay names that download `<asset-ID>-<date>-<owner>.tar.gz` - the exact form the
register's `proof_file` column uses. The operator then types that name into `N`, and uses it for
the evidence folder in OneDrive. The report can read it instead.

## What Changes

- When `check-output` is given an archive whose name follows badgersbay's download convention, the
  xlsx asset row report fills column `A` with the asset ID and column `N` with the archive name
  without its extension, and says the archive name is where both came from.
- An archive named any other way - a local audit's `honeybadger-<host>-<user>-<date>.tar.gz`, an
  unmatched submission's download, a renamed file - leaves `A` and `N` operator-maintained, as
  today.
- `C` Owner and `O` Remarks stay operator-maintained. The owner in the archive name is a slug, not
  the full name the register column holds.
- Nothing is looked up. No token, no network, and no change to badgersbay: the date in the name is
  the date badgersbay received the submission, which the ISO process accepts as the audit date.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `xlsx-asset-row-report`: columns `A` and `N` are filled from a badgersbay download name when
  there is one, and stay operator-maintained otherwise.

## Impact

**Code**
- `RUNME.sh`: `check-output` passes the name of the archive it was given to the xlsx report.
- `lib/_library`: `generate_xlsx_asset_row_report()` takes that name, recognises the download
  convention, and moves `A` and `N` between the determined and the operator-maintained sections.

**Behaviour**
- Running `check-output` on a directory, or on a locally made archive, produces the same report as
  today.
- `asset-inventory.json` is unchanged: the asset ID is the register's, and the client never
  reports it to the server.
