## 1. Firewall Evidence At Collection

- [ ] 1.1 Add a firewall collection step to the audit in `RUNME.sh` that writes `firewall-info.txt`
      with the `iptables -S` output, the `nft list ruleset` output and a closing
      `FIREWALL-RULESET:` line (`ACTIVE (<tool>[, <detail>])`, `NONE` or `UNAVAILABLE`), reusing
      `check_iptables_firewall()` and `check_nftables_firewall()`; verify by running the step on
      the maintainer's NixOS machine as root and finding `ACTIVE (iptables, nixos-fw chain)`
- [ ] 1.2 Cover the three result lines with stubbed `iptables` and `nft` in a shell test; verify
      `ACTIVE`, `NONE` and `UNAVAILABLE` are each written for the matching stub
- [ ] 1.3 Confirm `firewall-info.txt` is included in the archive and owned by the invoking user like
      the other output files; verify with `tar -tzf` on an archive produced by the audit

## 2. Firewall Evaluation From Evidence Only

- [ ] 2.1 Rewrite `check_firewall_status()` to the evaluation table in `design.md`: the result line
      first, then Lynis `firewall_active`, and no live probe; verify each of the six rows against
      fixture directories in `tests/test_check_evaluation.sh`
- [ ] 2.2 Assert that evaluation runs no firewall command: stub `sudo`, `iptables` and `nft` to fail
      loudly and verify `check-output` on a fixture never invokes them
- [ ] 2.3 Re-run the regression against every tarball in the repository; verify 14-07 and 25-08 move
      from `❌ Niet compliant` to `⚠️ Gedeeltelijk compliant` with the firewall listed under
      `Niet vastgesteld`, and that no other verdict moves

## 3. GNOME Settings As The Invoking User

- [ ] 3.1 Run the `gsettings` calls in the screen lock collection through
      `sudo -u "$sl_user" env HOME="$sl_home"`, adding `DBUS_SESSION_BUS_ADDRESS` when
      `/run/user/<uid>/bus` exists; verify with a stubbed `sudo` that records its arguments
- [ ] 3.2 Write `Settings read for user <name>` in the GNOME section, and `read as root` when no
      invoking user is known; verify both lines in the collection test
- [ ] 3.3 When the read as the user fails, report the GNOME settings as unavailable instead of
      falling back to root's values; verify with a `sudo` stub that fails
- [ ] 3.4 Verify on the Debian/GNOME laptop in the fleet: set `idle-delay` to a non-default value
      as the user, run `sudo ./RUNME.sh audit`, and confirm `screenlock-info.txt` reports that
      value; record the outcome under Open Questions in `design.md`

## 4. Documentation

- [ ] 4.1 Add `firewall-info.txt` to the output file list in `README.md` and
      `ISO27001-LAPTOP-COMPLIANCE.md`, and name it in the firewall row of the compliance table
- [ ] 4.2 Add a CHANGELOG entry under `## NEXT VERSION` covering the new evidence file, the removal
      of the live probe, GNOME settings read as the user, and the two archived scans that move
