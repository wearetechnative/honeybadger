---
# honeybadger-rn0a
title: 'honeybadger: carry the vulnerable package count, not just the finding text'
status: todo
type: task
priority: normal
tags:
    - honeybadger
    - iso27001
created_at: 2026-09-16T09:26:34Z
updated_at: 2026-09-16T09:26:34Z
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
