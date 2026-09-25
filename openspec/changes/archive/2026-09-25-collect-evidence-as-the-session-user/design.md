## Context

See `proposal.md` - Why. Requirements are in `specs/`.

Honeybadger separates collection (`RUNME.sh audit`, on the device, as root) from evaluation
(`lib/_library`, later, anywhere). `consolidate-compliance-check-evaluation` made evaluation
consistent. This change fixes two places where evaluation still works from evidence that does not
describe the audited device:

```
 TODAY
   audit (device, root)                    check-output (any machine)
   ────────────────────                    ──────────────────────────
   lynis-report.json  firewall_active ───▶ check_firewall_status()
                                              └─ Lynis says 0? ──▶ sudo iptables / nft
                                                                   ON THE ANALYSING MACHINE
   gsettings (as root) ──▶ screenlock-info.txt
      reads root's dconf / schema defaults

 AFTER
   audit (device, root)                    check-output (any machine)
   ────────────────────                    ──────────────────────────
   iptables -S, nft list ruleset ─▶ firewall-info.txt ─▶ check_firewall_status()
   lynis-report.json  firewall_active ────────────────▶   (file, then Lynis; never live)
   sudo -u <user> gsettings ──▶ screenlock-info.txt
```

## Goals / Non-Goals

**Goals**
- A firewall verdict that can be re-derived from the archive, on any machine, without privileges.
- GNOME lock settings that are the user's, with a record of whose they are.

**Non-Goals**
- Changing what counts as an active firewall. The existing probe logic moves; it is not redesigned.
- Reading XFCE or KDE settings as the user. Same problem, same fix, once GNOME is verified.
- Resolving the indeterminate vulnerable-packages verdict on NixOS.

## Decisions

### Firewall evidence is collected, not probed

The audit already runs as root, so the probes `check_iptables_firewall()` and
`check_nftables_firewall()` run there without `sudo` prompting anyone. The audit writes their raw
output and a result line:

```
=== iptables ===
<iptables -S output>

=== nftables ===
<nft list ruleset output>

=== Result ===
FIREWALL-RULESET: ACTIVE (iptables, nixos-fw chain)
```

`FIREWALL-RULESET` is `ACTIVE (<tool>[, <detail>])`, `NONE`, or `UNAVAILABLE` when neither tool is
installed. The raw rulesets are there so an auditor can check the conclusion; the result line is
there so evaluation does not have to re-derive it from a ruleset dump.

**Alternative considered:** evaluate the raw ruleset offline. Rejected - the probe logic already
exists and is what the verdict has been based on; moving it keeps the conclusion identical for
devices whose firewall Lynis already recognised.

### Evaluation order and old archives

`check_firewall_status()`:

| `firewall-info.txt`  | Lynis `firewall_active` | Verdict | Why                                       |
|----------------------|-------------------------|---------|-------------------------------------------|
| `ACTIVE`             | any                     | `0`     | Observed ruleset                          |
| `NONE`/`UNAVAILABLE` | `1`                     | `0`     | Lynis recognised a firewall               |
| `NONE`/`UNAVAILABLE` | `0`                     | `1`     | Both looked, neither found one            |
| `NONE`               | Lynis absent            | `1`     | The tools looked on the device, found none |
| `UNAVAILABLE`        | Lynis absent            | `2`     | Nothing looked                            |
| absent               | `1`                     | `0`     | Lynis recognised a firewall               |
| absent               | `0`                     | `2`     | Lynis misses `nixos-fw`; nothing else     |
| absent               | Lynis absent            | `2`     | No evidence                               |

The live probe is removed from evaluation entirely. That is the fix, not a side effect: a verdict
about device A formed from the ruleset of machine B is wrong even when it happens to agree.

### GNOME settings as the invoking user

The audit already resolves the invoking user and their home (`sl_user`, `sl_home`) for the lock
daemon configuration. `gsettings` runs through that user:

```bash
sudo -u "$sl_user" env HOME="$sl_home" gsettings get org.gnome.desktop.session idle-delay
```

This is the same pattern the audit uses for `fastfetch`. dconf reads the user's database
(`$HOME/.config/dconf/user`) directly for reads; a D-Bus session is needed to write, not to read.
Where `/run/user/<uid>/bus` exists it is passed as `DBUS_SESSION_BUS_ADDRESS` as well, so a session
that is running is used rather than bypassed.

When the invoking user is root, or unknown, settings are read as root and the evidence file says
so. When the read as the user fails, the GNOME section says that too, and does **not** fall back
to root's values - those are the schema defaults, which is the problem being fixed.

### Recording whose settings were read

The GNOME section gains `Settings read for user <name>`. This joins the `Config read for user`
line the Hyprland/Sway section already has, so both halves of the screen lock evidence state
whose they are.

## Risks / Trade-offs

**Archived scans move.** 14-07 and 25-08 go from `❌ Niet compliant` (firewall) to `⚠️ Gedeeltelijk
compliant` (firewall not established). A blocker disappears from the history of those scans. That is
correct - the blocker was Lynis's false negative - but it should be noted where the history of those
scans is used.

**The dconf assumption is unverified.** If `gsettings` under `sudo -u` cannot read the user's
database without the session bus on some distribution, the GNOME section reports that the settings
could not be read, the screen lock becomes indeterminate on that device, and the report says why.
That is a worse outcome than today's only in appearance: today's figure is the default.

**Firewall evidence is larger.** A full `nft list ruleset` on a machine running containers can be
long. It stays in the evidence file; the result line is what evaluation reads.

## Migration Plan

No data migration. Old archives are evaluated through the table above. New audits carry
`firewall-info.txt`.

## Resolved Questions

### gsettings under `sudo -u` reads the user's settings

Verified on 2026-09-25 on a Linux Mint 22.3 test machine outside the fleet (the same dconf and
GSettings stack as Debian and Ubuntu). With `idle-delay` set to 600 in the user's dconf database:

| Read as                                     | `idle-delay`              |
|---------------------------------------------|---------------------------|
| root                                        | 300 (the schema default)  |
| root, `sudo -u <user> env HOME=...`, no bus | 600                       |
| the collection block under `sudo`           | 600, "Settings read for user <user>" |

dconf reads the user's database without the session bus, so the approach holds. It also confirms
the premise of this change: every GNOME scan so far reported the default, not the user's setting.

The test was on Mint rather than on the Debian/GNOME laptop named in task 3.4, because that machine
was not available to run the new code. Nobody was logged in graphically, so the summary block ranked
the GNOME settings 4 and reported the timeout undetermined - the correct outcome for a machine with
no active desktop.

### Found along the way: Cinnamon is not read

Mint's default desktop is Cinnamon, which keeps its lock settings under `org.cinnamon.desktop.*`,
not `org.gnome.desktop.*`. The collection reads only the GNOME keys, and the active-desktop
inference does not recognise the `cinnamon` process. A Mint laptop therefore resolves to GNOME
settings at rank 4 and a `❓` screen lock, whatever its user configured. Supporting Cinnamon is a
separate change: the same `sudo -u` read, the Cinnamon keys, and `cinnamon` / `X-Cinnamon` as an
active desktop.
