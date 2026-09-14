## Context

See `proposal.md` — Why. Requirements are in `specs/xlsx-asset-row-report/spec.md`.

`check-output` already extracts every value this report needs. `generate_asset_inventory()` in
`lib/_library` reads the same source files and produces `asset-inventory.txt`, but it formats
values for human reading: `Yes (LUKS)`, `Yes (Auto-lock: 5 minutes)`,
`64/100 (Good) ❌ NON-COMPLIANT (required: ≥65)`, `Supported (Upgrade recommended)`. The register
accepts none of those — its columns are constrained by data validation.

Two structural facts about the spreadsheet shape this design:

```
 Active Assets (Table1, A1:O13)
 ┌───┬──────────────────────────┬─────────────────────────────┐
 │ A │ Asset                    │ operator                    │
 │ B │ Status                   │ FORMULA — array formula     │
 │ C │ Owner                    │ operator                    │
 │ D │ Serial Number            │ ← join key                  │
 │ E │ Model                    │ audit                       │
 │ F │ OS Edition + Version     │ audit                       │
 │ G │ Disk Encryption          │ audit · Yes/No/N.A.         │
 │ H │ Screen Lock              │ audit · Yes/No/N.A.         │
 │ I │ Firewall Active          │ audit · Yes/No/N.A.         │
 │ J │ Vuln Packages / Defender │ audit · None/Yes/N.A. ⚠     │
 │ K │ Lynis Hardening Score    │ audit · number or N.A.      │
 │ L │ OS Up-to-date            │ audit · Yes/No/N.A.         │
 │ M │ Last_Audit_Date          │ FORMULA =MID(N2,12,10)      │
 │ N │ proof_file               │ operator                    │
 │ O │ Remarks                  │ operator                    │
 └───┴──────────────────────────┴─────────────────────────────┘
```

The `Status` formula requires each of `G:J` to be `Yes` or `N.A.`, and `K` to be a number or the
literal `N.A.`. `Last_Audit_Date` is derived from `proof_file` by character offset, which only
works because the asset ID is exactly ten characters.

Updating the register is update-in-place, not append: an asset already has a row, keyed by serial
number, and a re-audit replaces its values.

## Goals / Non-Goals

**Goals:**
- Emit cell values that satisfy the register's data validation without further editing.
- Keep provenance visible next to every value, so the entry is auditable after the fact.
- Be honest about what the audit did not establish, rather than emitting a plausible value.
- Fit the shape of the two existing report generators, so the three are maintained the same way.

**Non-Goals:**
- Parsing, writing, or validating the `.xlsx` file. No spreadsheet library is introduced.
- Producing a paste-ready row. See the first decision below.
- Reconciling the spreadsheet's internal contradictions.

## Decisions

### A human-read markdown report, not a paste-ready row

A single tab-separated row would be quicker to paste, but the two formula columns `B` and `M` sit
at positions 2 and 13 — inside the range. Pasting fifteen columns overwrites them. Excel sometimes
restores a Table's calculated column afterwards; LibreOffice does not. Splitting the row into three
paste blocks around the formulas trades one hazard for three fiddly steps.

Markdown with one row per column sidesteps the hazard entirely, and buys something the TSV cannot:
room for the provenance column and for the column `J` note. The operator types nine short values.

Alternatives considered: single TSV row (rejected — destroys formulas); three TSV blocks (rejected
— error-prone ordering); CSV plus VLOOKUP on serial number (rejected — a larger change to how the
register works, and out of proportion to nine values).

### Two columns per row: cell value and finding

`Celwaarde` is what gets typed; `Vastgesteld als` is the evidence. Without the second column the
report is a list of bare assertions, and a `Yes` in `G` is indistinguishable from a guess. With it,
`Yes` ← `Yes (LUKS)` shows the basis, which is the form an ISO27001 auditor asks for. This also
makes an incorrect normalisation visible on inspection rather than only in the register.

### Normalisation derives from the same sources, not from `asset-inventory.txt`

The new function reads the source files directly rather than re-parsing the decorated strings in
`asset-inventory.txt`. Parsing `Yes (Auto-lock: 5 minutes)` back into `Yes` would couple the two
reports through a display format that exists to be readable, not to be parsed. The duplicated
extraction is a few `jq` and `grep` calls against files that are already open in the same run.

Where a shared helper already exists — `check_firewall_status()` — it is reused.

### Column `J` reports a finding, not a value

The register cannot be satisfied and documented at the same time here: its data validation says
`None` is compliant, its `Status` formula says `Yes` is. Emitting either literal would silently
pick a side, and all twelve existing rows say `Yes` while the notes say the opposite.

The audit data has a three-way answer that the report can state plainly:

```
 package_audit_tool_found == 0   →  not determined — no package audit tool present
 tool present, 0 vulnerable      →  no vulnerable packages found
 tool present, N vulnerable      →  N vulnerable packages found
```

The first case matters most. On NixOS, `vulnerable_packages_found` is `0` while
`package_audit_tool_found` is also `0` — nothing looked. Reporting that `0` as compliant would
write an untruth into a compliance register. This is the condition Lynis raises as PKGS-7398.

### `WARNING` maps to `Yes` for column `L`

The OS check has three outcomes and the column accepts two values. `PASS` and `FAIL` are
unambiguous. `WARNING` means supported but not on the newest release — the state this machine is in
at 6.18.50 against 6.18.51.

`Yes` was chosen because in this register the column means "still receives updates": all twelve
rows read `Yes`, and `No` makes the row NOK immediately, which would flag every machine one patch
behind. The upgrade advice belongs in `Remarks`, which the operator maintains. The provenance
column records that the source was a warning, so the nuance is not lost.

### Threshold is stated, not enforced

`MIN_HARDENING_SCORE` stays at 65 and column `K` receives the bare index. The applied threshold
and whether it was met go into the provenance column. The register's own `Compliance Summary`
uses `<75` and the `Status` formula uses no threshold at all; naming the applied value makes that
divergence visible without this change picking a winner.

## Risks / Trade-offs

- **Nine values are typed by hand, so transcription errors remain possible** → the provenance
  column makes a wrong entry checkable against the report afterwards, which a bare paste would not.
- **The `L` mapping is a judgement call that will misrepresent a machine that is many releases
  behind but not yet EOL** → the provenance column always records the underlying result, and the
  actions report separately surfaces the upgrade finding.
- **`E` Model and `F` OS strings may not match the register's existing conventions** (the register
  holds `LENOVO 21K9CTO1WW`, the audit reports `21K9CTO1WW (ThinkPad P16s Gen 2)`) → these are
  offered as values, and the operator overrides them where a house style exists. Normalising model
  strings is not attempted.
- **Column `J` produces no cell value, so that column still needs a human decision every time** →
  accepted deliberately; the alternative is writing an unverified compliance claim. It becomes a
  one-line change once the register's contradiction is resolved.
- **A third report adds output to an already busy directory** → it follows the established naming
  convention, so it sorts next to the other two per audit.

## Migration Plan

Additive. No existing output changes, no configuration changes, and nothing to roll back beyond
removing the generated file. Audits performed before this change can be re-run through
`check-output` against their retained tarballs to produce the report retroactively.

## Open Questions

None. The contradictions found in the register are recorded in `proposal.md` — Impact as known
issues that this change deliberately surfaces rather than resolves.
