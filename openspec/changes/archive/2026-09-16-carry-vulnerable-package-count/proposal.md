## Why

`vulnerable_packages.value` in `asset-inventory.json` is always `null`, even
when the audit counted vulnerable packages. The count survives only in the
finding text, where nothing can read it:

    "vulnerable_packages": {
      "value": null,
      "finding": "1 kwetsbare packages gevonden"
    }

The emitter hardcodes an empty string where every other finding passes its cell
value:

    --argjson vuln "$(_inventory_finding vulnerable_packages "" "$vuln_finding")"

This follows the design deliberately rather than by accident. The xlsx report
declines to give a cell value for column J because the register contradicts
itself about which literal means compliant - its data validation says `None`,
its Status formula counts `Yes` - so honeybadger asserts neither and explains
why. `emit-asset-inventory-json` carried that refusal through to the JSON.

That reasoning holds for the *spreadsheet cell*. It does not hold for the count.
"How many vulnerable packages were found" has an answer the audit already
computed; "which spreadsheet literal means compliant" is the question that has
none. Collapsing the two throws away a determination to avoid taking a position
on an unrelated ambiguity.

The `null` is also ambiguous in a way that now matters. Two platforms in one
acceptance run produced the same serialised value with opposite meanings:

| Platform | value  | finding                         | Truth                |
|----------|--------|---------------------------------|----------------------|
| Arch     | `null` | no package audit tool present   | nothing determined   |
| Ubuntu   | `null` | "1 kwetsbare packages gevonden" | determined, then lost |

A consumer can only tell them apart by parsing Dutch prose, which is not an
interface. badgersbay reads this file from `badgersbay-ucgi` onwards, so this
needs fixing before anything starts trusting the field.

## What Changes

- **Carry the count as its own field.** `count` is the measurement; `value`
  stays `null` for the reason it always was.

      "vulnerable_packages": {
        "value": null,
        "count": 1,
        "finding": "1 kwetsbare packages gevonden"
      }

- **A determined zero is distinct from nothing determined.** With a package
  audit tool present and no vulnerable packages, `count` is `0`. With no tool
  present, `count` is `null` - Lynis reports `0` there too, but it means
  "nothing looked", which is the condition it raises as PKGS-7398.
- **Render extra fields by type.** `_inventory_finding` rendered every extra as
  a JSON string, which would have made the count `"1"`. One shared rule now
  renders the cell and the extras alike: empty is `null`, an integer is a
  number, anything else is a string. `tool: "lynis"` is unaffected.
- **Bump `schema_version` to 2.** The field exists so a consumer can recognise
  a generation rather than guessing from which keys are present; a document
  that carries `count` is a different generation from one that does not.

## Capabilities

### Modified Capabilities
- `asset-inventory-json`: what `count` means, when it is a number and when it
  is null, and that a determined zero is distinguishable from an undetermined
  count

## Impact

- A consumer can act on the vulnerable package count without anyone first
  resolving the register's contradiction about column J.
- `schema_version` becomes 2. The capability's own design states that consumers
  retain the whole document and must be able to recognise a generation they do
  not fully understand, so an additive field with a bumped version is what that
  contract was written for. A consumer that rejects an unrecognised version
  outright would need updating; one that ignores unknown fields needs nothing.
- The xlsx report and `asset-inventory.txt` are unchanged. Column J still gets
  no cell value, which remains correct.

## Non-goals

- Deciding which literal column J should contain. The register's data
  validation and its Status formula disagree, and that is not honeybadger's
  contradiction to resolve.
- Splitting `value` and a measurement anywhere else. Every other finding has a
  cell value the sheet accepts, verified across all seven findings; column J is
  the only one that passes an empty cell.
- A machine-readable reason code for *why* a count is null. The finding text
  carries it today and no consumer has asked to branch on it; `count` alone
  resolves the determined/undetermined ambiguity this change is about.
