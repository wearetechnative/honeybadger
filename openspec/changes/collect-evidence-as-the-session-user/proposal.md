## Why

`consolidate-compliance-check-evaluation` made every report derive a verdict from one function and
state what it rests on. Two of those verdicts still rest on evidence that is not what it claims to
be. The firewall check probes the machine it runs on: `check_firewall_status()` calls
`sudo iptables` and `sudo nft` during `check-output`, so re-analysing an archive reports the
analyst's firewall, and analysing a colleague's tarball asks for the analyst's sudo password to do
it. And the audit reads GNOME's lock settings with `gsettings` as root, which returns root's
settings or the schema defaults rather than the user's - the `300 seconds` in every GNOME scan so
far is most likely GNOME's default, not a setting anyone chose.

Both are collection problems: only the device, at scan time, can see its own ruleset and its user's
settings. The evaluation can only be as honest as what was collected.

## What Changes

- The audit writes a new evidence file, `firewall-info.txt`: the `iptables -S` ruleset (including
  the NixOS `nixos-fw` chain), the `nft list ruleset` output, and a closing result line stating
  whether an active ruleset was found and by which tool.
- `check_firewall_status()` reads `firewall-info.txt`, then Lynis `firewall_active`. It never probes
  the machine it runs on. The `check_iptables_firewall()` and `check_nftables_firewall()` live
  probes move into the audit.
- An archive collected before `firewall-info.txt` existed is evaluated from Lynis alone: `1` passes,
  `0` is indeterminate rather than a failure, because Lynis does not recognise the `nixos-fw` chain
  and that false negative is why the live fallback was added.
- GNOME settings are read as the user who ran `sudo`, with that user's home, the same way the audit
  already runs `fastfetch`. The evidence file records whose settings were read.
- **Behaviour change for archived scans:** the 14-07 and 25-08 lobos tarballs, where Lynis reports
  no firewall, move from `❌ Niet compliant` to `⚠️ Gedeeltelijk compliant` with the firewall
  listed as not established. Their evidence never showed a missing firewall; it showed Lynis not
  recognising one.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `iso27001-compliance-reporting`: the firewall verdict is formed from evidence collected during the
  audit, never from a live probe at evaluation time; a Lynis `0` without collected firewall
  evidence is indeterminate.
- `audit-output`: the audit collects `firewall-info.txt`, and collects per-user desktop settings as
  the invoking user rather than as root.

## Impact

**Code**
- `RUNME.sh`: a firewall collection step writing `firewall-info.txt`; the GNOME section of the
  screen lock collection runs `gsettings` through `sudo -u`.
- `lib/_library`: `check_firewall_status()` reads the evidence file; the live probe functions are
  called only from the audit.

**Evidence format**
- New file `firewall-info.txt` in the output directory and the archive.
- `screenlock-info.txt` gains a line naming the user whose GNOME settings were read.

**Unverified assumption**
- `gsettings` under `sudo -u` reads the user's dconf database (`~/.config/dconf/user`) directly,
  without that user's D-Bus session. Expected, not yet tested: it needs a run on a real GNOME
  machine, and a Debian/GNOME laptop is in the fleet.

**Explicitly out of scope**
- A package audit on NixOS (vulnix) to resolve the indeterminate vulnerable-packages verdict.
- Settings of other desktops (XFCE, KDE) read as root. They have the same problem and follow the
  same pattern once the GNOME case is verified.
