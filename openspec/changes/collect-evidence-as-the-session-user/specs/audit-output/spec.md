## ADDED Requirements

### Requirement: Collect firewall evidence during the audit
The audit SHALL record the device's packet filter ruleset in `firewall-info.txt`, so that the
firewall verdict can be formed and re-examined from the archive alone.

#### Scenario: iptables ruleset present
- **WHEN** the audit runs on a device with an iptables ruleset, including the NixOS `nixos-fw` chain
- **THEN** `firewall-info.txt` contains the `iptables -S` output
- **AND** a closing result line states that an active ruleset was found, and by which tool

#### Scenario: nftables ruleset present
- **WHEN** the audit runs on a device with an nftables ruleset
- **THEN** `firewall-info.txt` contains the `nft list ruleset` output
- **AND** the result line states that an active ruleset was found with nftables

#### Scenario: No ruleset
- **WHEN** neither tool reports an active ruleset
- **THEN** the result line states that no active ruleset was found
- **AND** it states which tools were present and queried

### Requirement: Read per-user desktop settings as the invoking user
The audit runs as root, but desktop lock settings belong to the user who ran it. The audit SHALL
read those settings as that user, with that user's home directory, and SHALL record in the evidence
file whose settings were read.

#### Scenario: GNOME settings under sudo
- **WHEN** the audit runs under `sudo` on a GNOME desktop
- **THEN** the GNOME lock settings in `screenlock-info.txt` are the invoking user's settings
- **AND** `screenlock-info.txt` names the user whose settings were read

#### Scenario: Audit run as root without sudo
- **WHEN** the audit runs as root and no invoking user is known
- **THEN** the settings are read as root
- **AND** `screenlock-info.txt` states that they were read as root
