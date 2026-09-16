# Design

## Two questions wearing one field

Column J of the asset register asks a question honeybadger cannot answer: which
literal means compliant. The sheet's data validation offers `None`; its Status
formula counts `Yes`. Filling either in would be picking a side in someone
else's contradiction, so the xlsx report reports the finding and leaves the cell
to the operator. That is right, and it stays.

The JSON inherited the refusal by passing `""` as the cell, which
`_inventory_finding()` renders as `null`. But the JSON is not a spreadsheet
cell. "How many vulnerable packages were found" is a separate question with an
answer the audit already computed and then discarded.

So: two fields for two questions. `value` stays `null` because the cell is
genuinely undecidable. `count` carries the measurement.

## What `count` means

| Condition                                  | `count` | Why                          |
|--------------------------------------------|---------|------------------------------|
| No `lynis-report.json`                     | `null`  | nothing was measured         |
| Report present, no package audit tool      | `null`  | nothing looked               |
| Report present, tool present, none found   | `0`     | measured, and the answer is 0 |
| Report present, tool present, N found      | `N`     | measured                     |

The second row is the one worth being careful about. Lynis reports
`vulnerable_packages_found: 0` when no package audit tool is installed, which
looks identical to a clean machine. It is the condition Lynis itself raises as
PKGS-7398, and the existing code already distinguishes it for the finding text:

    if [[ "$audit_tool" != "1" ]]; then
        # A count of 0 here means "nothing looked", not "nothing found".

`count` follows that same gate rather than reading `vulnerable_packages_found`
directly. Reporting `0` there would be the more dangerous version of this bug:
a fleet of machines that never looked, reported as clean.

## Typing the extras

`_inventory_finding()` took an optional `extra_key`/`extra_value` pair and
rendered the value with `--arg`, which is always a string. The only caller was
`tool lynis`, so that was invisible. Passing a count through it would have
produced `"count": "1"` - a number in a string, which a consumer then has to
parse and can get wrong.

Rather than adding a second typed-extra parameter, the cell's own rendering rule
is factored out and applied to both:

    _inventory_scalar <raw>
      empty            -> null
      integer          -> number
      anything else    -> JSON string

That is what the cell already did; the cell path keeps its extra step of
mapping `N.A.` and `zie notitie` to empty first, because those are
spreadsheet-specific spellings of "no value" rather than general ones.
`tool lynis` renders as the string `"lynis"` exactly as before.

## Bumping the schema

The capability's design says:

> A `schema_version` field lets a consumer recognise a generation it does not
> fully understand and keep what it can, rather than guessing from which keys
> happen to be present.

A document carrying `count` is a generation a version-1 consumer does not fully
understand. Leaving the version at 1 would force exactly the guessing-from-keys
the field exists to prevent, so it goes to 2.

This is the first bump, so it is also the first test of whether consumers
tolerate one. The same design paragraph says they are expected to retain the
whole document, so the contract is already written for this; a consumer that
rejects an unknown version was never conforming.

## Why not a reason code

`count: null` covers two cases - no report, and no tool - and the finding text
is the only thing that separates them. A `reason` enum would fix that, and was
considered.

It is not in this change. Nothing has asked to branch on why the count is
missing, and the ambiguity this change exists to remove is a different one:
`null` meaning both "not determined" and "determined, then thrown away". `count`
removes that completely. Adding an enum nobody consumes would be inventing an
interface ahead of its use, and the finding text remains available for a human
reading the archive.

## Scope check: does the split apply elsewhere

All seven findings were read. `vulnerable_packages` is the only one that passes
an empty cell to `_inventory_finding()`; `os`, `disk_encryption`, `screen_lock`,
`firewall`, `hardening_score` and `os_uptodate` each pass either a value the
sheet accepts or `N.A.` when the audit could not determine it. There is no
second instance of a measurement being discarded to avoid a spreadsheet
ambiguity, so the split stays specific to column J.
