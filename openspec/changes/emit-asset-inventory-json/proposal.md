## Why

The audit already determines every compliance value the ISO register needs. It
writes them twice, both times for humans: `asset-inventory.txt` as a formatted
table, and `honeybadger-{user}-{date}-xlsx.md` as cell values to transcribe by
hand.

The collection server discards both. Of the fourteen files in a submitted tar it
recognises one. The result is that a finished answer is thrown away at the door
and the operator retypes it into a spreadsheet from a markdown file.

Adding a machine-readable form of the same determinations lets the server
consume them without reimplementing the audit logic. That distinction matters:
whether a disk counts as encrypted, or a hardening score as compliant, is
platform-specific knowledge that lives here and should stay here. A server-side
parser of `asset-inventory.txt` would be a second implementation of the same
rules in another language, drifting from this one and breaking on any cosmetic
change to a human-facing table.

## What Changes

- Write `asset-inventory.json` into the output directory and the tar, carrying
  the same determinations as `asset-inventory.txt`
- Include `schema_version` so consumers can tell generations apart
- Include the raw finding alongside each determined value, as the xlsx report
  already does, so a consumer can show provenance and not only a verdict
- Leave `asset-inventory.txt` and the xlsx report unchanged

## Capabilities

### New Capabilities
- `asset-inventory-json`: machine-readable audit summary

## Impact

- One additional file per audit. No change to what is collected or how anything
  is determined.
- The Windows client does not produce an asset inventory at all and cannot
  satisfy this yet; see bean `wtoorren-cikq`, which should target this schema
  rather than inventing a second one.
- Consumer side: badgersbay change `asset-register-identity` establishes serial
  identity and the asset register; extraction of these values is the follow-on
  that this change unblocks.

## Non-goals

- Changing any determination rule, threshold or output the audit already
  produces. This is a serialisation of existing results.
