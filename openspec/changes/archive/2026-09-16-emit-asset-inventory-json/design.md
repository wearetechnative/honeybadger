## Decision: the client owns the audit logic

Two shapes were considered for getting compliance values into the collection
server.

**Server parses the raw artefacts.** The server would read `blockdevices.txt`,
`screenlock-info.txt`, `lynis-report.json` and derive its own verdicts. This
puts the same rule in two codebases and two languages. The rules are not
uniform: disk encryption means LUKS here, FileVault there, BitLocker elsewhere,
and the hardening score comes from Lynis on two platforms and HardeningKitty on
the third. Every platform added, or threshold changed, would have to be changed
in both places or silently disagree.

**Client emits a structured summary.** The client already holds all of this and
already writes it out for humans. Serialising it costs one file. The server
stores and displays; it decides nothing.

The second is chosen. The server stays a collection point, which is what it is
for.

Parsing `asset-inventory.txt` server-side was rejected as a third option: it is
a formatted table with aligned columns and a notes footer, designed to be read.
Any change to its presentation would break a consumer.

## Decision: carry provenance, not only verdicts

`honeybadger-{user}-{date}-xlsx.md` already reports both the cell value and the
finding it was derived from, because "Yes" and "Yes (LUKS)" answer different
questions. The JSON carries the same pair. A consumer showing only verdicts can
ignore the finding; one showing an auditor why a value was chosen cannot
reconstruct it.

The same applies to values the audit deliberately declines to assert. The xlsx
report withholds a cell value for vulnerable packages, because the spreadsheet's
own validation and its status formula disagree about which value means
compliant. That refusal is information and must survive serialisation: a
consumer must be able to distinguish "determined to be absent" from "not
determined".

## Decision: version the schema

The client is ahead of the server and will stay ahead. A `schema_version` field
lets a consumer recognise a generation it does not fully understand and keep
what it can, rather than guessing from which keys happen to be present.

Consumers are expected to retain the whole document, not only the fields they
model today.

## Shape

    {
      "schema_version": 1,
      "generated_at": "2026-09-15T13:25:34+02:00",
      "honeybadger_version": "0.4.1",
      "platform": "linux",
      "identity": {
        "serial": "PF50L2MR",
        "hostname": "lobos",
        "username": "wtoorren",
        "model": "21K9CTO1WW (ThinkPad P16s Gen 2)"
      },
      "findings": {
        "os":              { "value": "NixOS 26.05 (Yarara)", "finding": "NixOS 26.05 (Yarara)" },
        "disk_encryption": { "value": "Yes",  "finding": "Yes (LUKS)" },
        "screen_lock":     { "value": "Yes",  "finding": "Yes (auto-lock: 5 minutes)" },
        "firewall":        { "value": "Yes",  "finding": "Yes" },
        "vulnerable_packages": { "value": null, "finding": "not determined - no package audit tool present" },
        "hardening_score": { "value": 72, "tool": "lynis", "finding": "72/100 - threshold >=65 met" },
        "os_uptodate":     { "value": "Yes",  "finding": "WARNING - supported, upgrade recommended" }
      }
    }

`value: null` with a populated `finding` is the explicit "not determined" case.
It is distinct from a field being absent, which means this generation of the
client does not produce it at all.
