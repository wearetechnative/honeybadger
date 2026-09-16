---
# honeybadger-rn0a
title: 'honeybadger: carry the vulnerable package count, not just the finding text'
status: completed
type: task
priority: normal
tags:
    - honeybadger
    - iso27001
created_at: 2026-09-16T09:26:34Z
updated_at: 2026-09-16T12:12:17Z
---

`vulnerable_packages.value` in `asset-inventory.json` is always `null`, even
when the audit counted vulnerable packages. The count survives only in the
finding text, where nothing can read it.

## Current behaviour

`lib/_library` passes a hardcoded empty string where every other finding passes
its cell value:

    --argjson vuln "$(_inventory_finding vulnerable_packages "" "$vuln_finding")"

Measured on Ubuntu 24.04:

    "vulnerable_packages": {
      "value": null,
      "finding": "1 kwetsbare packages gevonden"
    }

The audit determined a number. The machine-readable record does not carry it.

## This is a decision to revisit, not an implementation slip

It follows the design deliberately. The xlsx report declines to give a cell
value for column J because the spreadsheet contradicts itself about which value
means compliant - its data validation says `None`, its Status formula counts
`Yes` - so honeybadger asserts neither and explains why. The change
`emit-asset-inventory-json` carried that refusal through to the JSON, and its
spec says a deliberately undetermined value is `null` with the finding intact.

That reasoning holds for the *spreadsheet cell*. It does not hold for the
count. "How many vulnerable packages were found" has an answer the audit
already computed; "which spreadsheet value means compliant" is the question
that has no answer. Collapsing the two throws away a determination to avoid
taking a position on an unrelated ambiguity.

## Proposal

Carry the count as its own field, and leave the spreadsheet cell undecided:

    "vulnerable_packages": {
      "value": null,
      "count": 1,
      "finding": "1 kwetsbare packages gevonden"
    }

`value` stays `null` for the reason it always was: the sheet cannot be filled
in unambiguously. `count` is the measurement, and a consumer can act on it
without anyone resolving the spreadsheet's contradiction first.

Where no package audit tool is present, `count` is `null` too - that is genuinely
not determined, and distinct from a determined zero.

## Consequences

- `emit-asset-inventory-json` is archived; this needs its own change, and the
  `asset-inventory-json` capability spec has to say what `count` means.
- The schema gains a field. Consumers that keep the whole document - badgersbay
  does - lose nothing by not modelling it yet.
- Worth deciding at the same time whether the same split applies elsewhere. It
  does not today: every other finding has a cell value the sheet accepts.

## The null is ambiguous, and that matters now the server reads it

Same serialised value, opposite meanings, seen on two platforms in one test run:

| Platform | `value` | `finding`                                 | Truth                |
|----------|---------|-------------------------------------------|----------------------|
| Arch     | `null`  | no package audit tool present             | nothing determined   |
| Ubuntu   | `null`  | "1 kwetsbare packages gevonden"           | determined, then lost|

The emitter hardcodes `""` for this field, so `_inventory_finding` renders null
in both cases. A consumer reading `inventory` cannot tell "not determined" from
"determined but never written" - it can only tell by parsing the Dutch prose in
`finding`, which is not an interface.

This is no longer only a client-side loss: badgersbay reads `inventory` from
`badgersbay-ucgi` onwards. Fix this before anything starts trusting the field.

## Summary of Changes

Fixed in OpenSpec change `carry-vulnerable-package-count`, archived as
`openspec/changes/archive/2026-09-16-carry-vulnerable-package-count`.

### The count travels beside the cell

`value` stays `null` for the reason it always was - the register's data
validation says `None` and its Status formula counts `Yes`, so honeybadger
asserts neither. `count` is the measurement:

    "vulnerable_packages": {
      "value": null,
      "count": 1,
      "finding": "1 kwetsbare packages gevonden"
    }

`count` is `0` only when a package audit tool looked and found nothing. Where
no tool is present Lynis also reports zero, but that means nothing looked - the
condition it raises as PKGS-7398 - so `count` is null there. Reporting it as
zero would be the worse bug: a fleet that never looked, filed as clean.

### Typed extras

`_inventory_finding` rendered every extra with `--arg`, so the count would have
arrived as `"1"` - a number inside a string, which the consumer then has to
parse and can parse wrongly. The cell's own rendering rule is factored into
`_inventory_scalar()` and applied to both: empty is null, a whole number is a
number, anything else a string. `tool: "lynis"` is unaffected.

A non-canonical integer such as `007` is now carried as a string. `jq` reads it
as `7` and would have changed the value without saying so.

### Schema version

Bumped to 2. The capability's design says the field exists so a consumer can
recognise a generation rather than guessing from which keys are present; a
document carrying `count` is such a generation. The same paragraph says
consumers retain the whole document and must tolerate a version they do not
fully understand, so the contract was already written for this - but it is the
first bump, so it is worth badgersbay confirming it does not reject an
unrecognised version.

### The ambiguity is gone

The two platforms from the bug report, through the real `check-output` path:

    Arch    (no audit tool)  value=null  count=null
    Ubuntu  (one found)      value=null  count=1

Previously both serialised identically and could only be told apart by parsing
the Dutch finding text.

### Scope check

All seven findings were read. `vulnerable_packages` is the only one passing an
empty cell; `os`, `disk_encryption`, `screen_lock`, `firewall`,
`hardening_score` and `os_uptodate` each pass a value the sheet accepts or
`N.A.`. There is no second instance of a measurement discarded to avoid a
spreadsheet ambiguity, so the split stays specific to column J. Recorded in
`design.md`.

### Not done, deliberately

A machine-readable reason for *why* a count is null - no report versus no tool.
Both remain distinguishable only by the finding text. Nothing has asked to
branch on it, and `count` removes the ambiguity this bean was about. Noted in
`design.md` as considered and declined.

### Tests

`tests/test_asset_inventory_json.sh` grows from 21 to 51 assertions: scalar
rendering including the padded-integer case, a numeric extra versus a textual
one, count present, determined zero, no audit tool, no report, and four
end-to-end tests that run `generate_xlsx_asset_row_report` over fixture output
directories for both platform cases. Full suite: 9 files, passing. shellcheck
over `lib/_library`: unchanged from the previous commit.
