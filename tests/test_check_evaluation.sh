#!/usr/bin/env bash
# shellcheck disable=SC2034  # SL_* and output are read by the code under test
# One evaluation per control.
#
# The check_* functions are the only place a compliance verdict is formed, and
# every report calls them. These tests pin the verdicts themselves - the
# three-state exit code, and which screen lock mechanism a verdict rests on -
# and that the reports agree with each other because they share them.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$TESTS_DIR/lib.sh"

WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
}

teardown() {
    [[ -n "$WORKDIR" ]] && rm -rf "$WORKDIR"
    WORKDIR=""
}

# Run a check and capture both halves of its answer.
# Usage: run_check <function> <dir>   -> sets DETAIL and VERDICT
run_check() {
    DETAIL=$("$1" "$2")
    VERDICT=$?
}

# Write a screenlock-info.txt carrying only a summary block.
# Usage: summary_fixture <dir> <mechanism> <rank> <seconds> <status>
summary_fixture() {
    mkdir -p "$1"
    cat > "$1/screenlock-info.txt" <<EOF
=== Authoritative Source Summary ===
SUMMARY-ACTIVE-DESKTOP: not established
SUMMARY-MECHANISM: $2
SUMMARY-RANK: $3 (fixture)
SUMMARY-BASIS: fixture
SUMMARY-TIMEOUT-SECONDS: $4
SUMMARY-LIMIT-SECONDS: 900
SUMMARY-STATUS: $5
EOF
}

reset_sl() {
    unset "${!SL_@}"
}

# ------------------------------------------------------------- status icon

test_status_icon_renders_three_states() {
    assert_equals "✅" "$(status_icon 0)" "pass"
    assert_equals "❌" "$(status_icon 1)" "fail"
    assert_equals "❓" "$(status_icon 2)" "indeterminate"
    # A broken check is not passed off as merely unknown.
    assert_equals "❌" "$(status_icon 7)" "anything else"
}

# --------------------------------------------------------- three-state checks

test_disk_encryption_distinguishes_absent_from_uncollected() {
    setup
    mkdir -p "$WORKDIR/luks" "$WORKDIR/plain" "$WORKDIR/none"
    echo "nvme0n1p2 crypto_LUKS 2" > "$WORKDIR/luks/blockdevices.txt"
    echo "nvme0n1p2 ext4" > "$WORKDIR/plain/blockdevices.txt"

    run_check check_disk_encryption "$WORKDIR/luks"
    assert_equals 0 "$VERDICT" "LUKS present"
    run_check check_disk_encryption "$WORKDIR/plain"
    assert_equals 1 "$VERDICT" "file present, no LUKS: a failure"
    run_check check_disk_encryption "$WORKDIR/none"
    assert_equals 2 "$VERDICT" "file absent: not established"
    assert_contains "$DETAIL" "blockdevices.txt" "the detail names the missing evidence"
    teardown
}

test_lynis_backed_checks_are_indeterminate_without_lynis() {
    setup
    mkdir -p "$WORKDIR/none"
    local saved_path="$PATH"
    # No live ruleset either: the probes find nothing to show.
    stub_tool "$WORKDIR/bin" sudo 'exit 1'
    PATH="$WORKDIR/bin:$PATH"

    run_check check_firewall_status "$WORKDIR/none"
    assert_equals 2 "$VERDICT" "firewall without lynis-report.json"
    run_check check_vulnerable_packages "$WORKDIR/none"
    assert_equals 2 "$VERDICT" "vulnerable packages without lynis-report.json"

    echo '{"firewall_active": "0"}' > "$WORKDIR/none/lynis-report.json"
    echo "FIREWALL-RULESET: NONE" > "$WORKDIR/none/firewall-info.txt"
    run_check check_firewall_status "$WORKDIR/none"
    assert_equals 1 "$VERDICT" "Lynis and the collected ruleset both found none: a failure"

    PATH="$saved_path"
    teardown
}

test_lynis_scan_absent_is_a_finding_unreadable_is_not() {
    setup
    mkdir -p "$WORKDIR/none" "$WORKDIR/broken" "$WORKDIR/ok"
    echo '{"hardening_index": 70' > "$WORKDIR/broken/lynis-report.json"
    echo '{}' > "$WORKDIR/ok/lynis-report.json"

    run_check check_lynis_scan_exists "$WORKDIR/ok"
    assert_equals 0 "$VERDICT" "scan present"
    run_check check_lynis_scan_exists "$WORKDIR/none"
    assert_equals 1 "$VERDICT" "no report means no scan"
    run_check check_lynis_scan_exists "$WORKDIR/broken"
    assert_equals 2 "$VERDICT" "a truncated report shows a scan started, not that it finished"
    teardown
}

test_an_indeterminate_control_is_not_a_blocker() {
    setup
    local dir="$WORKDIR/output-host-user-01-01-2026"
    mkdir -p "$dir"
    echo '{"firewall_active": "1", "hostname": "host"}' > "$dir/lynis-report.json"
    summary_fixture "$dir" hypridle 2 300 ENABLED
    # blockdevices.txt deliberately not collected

    (cd "$WORKDIR" && generate_compliance_report "$dir" >/dev/null)
    local report
    report=$(cat "$WORKDIR"/honeybadger-*-compliance.md)

    assert_contains "$report" "| Disk encryptie | ❓ |" "rendered as indeterminate"
    [[ "$report" != *"Geen disk encryptie"* ]]
    assert_success "not listed as a blocker" $?
    assert_contains "$report" "### Niet vastgesteld" "named as a gap instead"
    assert_contains "$report" "Gedeeltelijk compliant" "an unverified control is not a demonstrated one"
    teardown
}

# ------------------------------------------------- vulnerable packages

# Usage: lynis_fixture <dir> <json>
lynis_fixture() {
    mkdir -p "$1"
    echo "$2" > "$1/lynis-report.json"
}

test_no_package_audit_tool_is_not_a_clean_bill() {
    # Lynis reports zero and raises no PKGS-7392 when nothing looked.
    setup
    lynis_fixture "$WORKDIR/d" '{"package_audit_tool_found": "0", "vulnerable_packages_found": "0", "warning[]": []}'
    run_check check_vulnerable_packages "$WORKDIR/d"
    assert_equals 2 "$VERDICT" "nothing looked"
    assert_contains "$DETAIL" "no package audit tool" "and says so"
    teardown
}

test_vulnerable_packages_are_found_by_count_or_by_warning() {
    setup
    lynis_fixture "$WORKDIR/count" '{"package_audit_tool_found": "1", "package_audit_tool": "apt-get",
        "vulnerable_packages_found": "3", "warning[]": []}'
    lynis_fixture "$WORKDIR/object" '{"package_audit_tool_found": "1", "vulnerable_packages_found": "0",
        "warning[]": [{"id": "PKGS-7392", "description": "Found vulnerable packages"}]}'
    lynis_fixture "$WORKDIR/string" '{"package_audit_tool_found": "1", "vulnerable_packages_found": "0",
        "warning[]": ["PKGS-7392|Found vulnerable packages|-|-|"]}'
    lynis_fixture "$WORKDIR/clean" '{"package_audit_tool_found": "1", "package_audit_tool": "apt-get",
        "vulnerable_packages_found": "0", "warning[]": [{"id": "NETW-2704", "description": "x"}]}'

    run_check check_vulnerable_packages "$WORKDIR/count"
    assert_equals 1 "$VERDICT" "a count above zero"
    assert_equals "3 vulnerable packages found (apt-get)" "$DETAIL" "with the count and the tool"
    run_check check_vulnerable_packages "$WORKDIR/object"
    assert_equals 1 "$VERDICT" "PKGS-7392 as an object, the current Lynis format"
    run_check check_vulnerable_packages "$WORKDIR/string"
    assert_equals 1 "$VERDICT" "PKGS-7392 as a string, the older format"
    run_check check_vulnerable_packages "$WORKDIR/clean"
    assert_equals 0 "$VERDICT" "a tool looked and found nothing"
    assert_equals "None (apt-get)" "$DETAIL" "names the tool that looked"
    teardown
}

test_checklist_and_xlsx_agree_on_vulnerable_packages() {
    setup
    local dir="$WORKDIR/output-host-user-01-01-2026"
    compliant_fixture "$dir"
    lynis_fixture "$dir" '{"hostname": "host", "hardening_index": "70", "firewall_active": "1",
        "package_audit_tool_found": "0", "vulnerable_packages_found": "0", "warning[]": []}'
    render_reports "$dir"

    assert_contains "$COMPLIANCE" "| Kwetsbare software | ❓ | Unknown - no package audit tool present" "checklist"
    assert_contains "$XLSX" "Unknown - no package audit tool present" "xlsx column J, same words"
    assert_equals "null" "$(jq -r .findings.vulnerable_packages.count "$dir/asset-inventory.json")" \
        "nothing counted is not zero"
    teardown
}

# ------------------------------------------------- firewall evidence

# Usage: firewall_fixture <dir> <ruleset line or "-"> <lynis firewall_active or "-">
firewall_fixture() {
    mkdir -p "$1"
    [[ "$2" != "-" ]] && printf '=== Result ===\nFIREWALL-RULESET: %s\n' "$2" > "$1/firewall-info.txt"
    [[ "$3" != "-" ]] && echo "{\"firewall_active\": \"$3\"}" > "$1/lynis-report.json"
    return 0
}

test_firewall_verdict_follows_the_evidence_table() {
    setup
    local -a rows=(
        "ACTIVE (iptables, nixos-fw chain)|0|0|Yes (iptables, nixos-fw chain)"
        "NONE|1|0|Yes"
        "NONE|0|1|No"
        "UNAVAILABLE|0|1|No"
        "NONE|-|1|No"
        "UNAVAILABLE|-|2|"
        "-|1|0|Yes"
        "-|0|2|"
        "-|-|2|"
    )
    local row ruleset lynis expected detail n=0
    for row in "${rows[@]}"; do
        IFS='|' read -r ruleset lynis expected detail <<< "$row"
        n=$((n + 1))
        firewall_fixture "$WORKDIR/r$n" "$ruleset" "$lynis"
        run_check check_firewall_status "$WORKDIR/r$n"
        assert_equals "$expected" "$VERDICT" "evidence '$ruleset', Lynis '$lynis'"
        [[ -n "$detail" ]] && assert_equals "$detail" "$DETAIL" "detail for '$ruleset'"
    done
    teardown
}

test_an_old_nixos_archive_is_not_failed_on_lynis_alone() {
    setup
    firewall_fixture "$WORKDIR/old" - 0
    run_check check_firewall_status "$WORKDIR/old"
    assert_equals 2 "$VERDICT" "Lynis misses nixos-fw"
    assert_contains "$DETAIL" "no firewall-info.txt" "and the detail says what is missing"
    teardown
}

test_evaluation_never_touches_the_analysing_machine() {
    setup
    local dir="$WORKDIR/output-host-user-01-01-2026" tool
    compliant_fixture "$dir"
    echo '{"hostname": "host", "hardening_index": "70", "firewall_active": "0",
           "package_audit_tool_found": "1", "vulnerable_packages_found": "0"}' > "$dir/lynis-report.json"
    for tool in sudo iptables nft; do
        stub_tool "$WORKDIR/bin" "$tool" "echo $tool >> '$WORKDIR/invoked'; exit 1"
    done
    PATH="$WORKDIR/bin:$PATH" render_reports "$dir"

    local invoked=""
    [[ -e "$WORKDIR/invoked" ]] && invoked=$(tr '\n' ' ' < "$WORKDIR/invoked")
    assert_equals "" "$invoked" "no firewall command and no sudo during check-output"
    teardown
}

# Run hb_collect_firewall_evidence against stubbed tools.
# Usage: collect_firewall <iptables stub body or "-"> <nft stub body or "-">
collect_firewall() {
    local bin="$WORKDIR/fwbin"
    link_real_tools "$bin"
    [[ "$1" != "-" ]] && stub_tool "$bin" iptables "$1"
    [[ "$2" != "-" ]] && stub_tool "$bin" nft "$2"
    FIREWALL_EVIDENCE=$(PATH="$bin" hb_collect_firewall_evidence)
}

test_collection_records_an_active_nixos_ruleset() {
    setup
    collect_firewall '
case "$*" in
  "-S") echo "-N nixos-fw"; echo "-A nixos-fw -p tcp --dport 22 -j nixos-fw-accept" ;;
  "-L nixos-fw -n") printf "Chain nixos-fw
target prot
nixos-fw-accept tcp
" ;;
  *) exit 1 ;;
esac' -
    assert_contains "$FIREWALL_EVIDENCE" "-A nixos-fw -p tcp" "the raw ruleset is kept"
    assert_contains "$FIREWALL_EVIDENCE" "FIREWALL-RULESET: ACTIVE (iptables, nixos-fw chain)" "result line"
    teardown
}

test_collection_records_an_nftables_ruleset() {
    setup
    collect_firewall 'exit 1' 'echo "table inet filter {"; echo "}"'
    assert_contains "$FIREWALL_EVIDENCE" "FIREWALL-RULESET: ACTIVE (nftables)" "result line"
    teardown
}

test_collection_distinguishes_none_from_unavailable() {
    setup
    collect_firewall 'case "$*" in "-L INPUT -n") printf "Chain INPUT
target prot
" ;; *) exit 0 ;; esac' 'exit 0'
    assert_contains "$FIREWALL_EVIDENCE" "FIREWALL-RULESET: NONE" "tools present, nothing found"
    assert_contains "$FIREWALL_EVIDENCE" "FIREWALL-TOOLS-QUERIED: iptables nft" "and which were asked"
    teardown
    setup
    collect_firewall - -
    assert_contains "$FIREWALL_EVIDENCE" "FIREWALL-RULESET: UNAVAILABLE" "no tools at all"
    teardown
}

# ------------------------------------------------- screen lock: source ranking

test_a_running_daemon_outranks_inactive_desktop_settings() {
    # The maintainer's own machine: hypridle running, GNOME schemas installed as
    # a dependency, XDG_CURRENT_DESKTOP cleared by sudo.
    reset_sl
    SL_RUNNING="hypridle"
    SL_DE_STATUS_GNOME="ENABLED"; SL_DE_SECONDS_GNOME=300

    local out
    out=$(hb_screen_lock_summary)
    assert_contains "$out" "SUMMARY-MECHANISM: hypridle" "the daemon is the source"
    assert_contains "$out" "SUMMARY-TIMEOUT-SECONDS: undetermined" "GNOME's figure is not borrowed"
    assert_contains "$out" "SUMMARY-STATUS: UNDETERMINED" "enforced, timeout unknown"
    reset_sl
}

test_daemon_timeout_from_arguments_outranks_configuration() {
    reset_sl
    SL_RUNNING="hypridle swayidle"
    SL_CONF_SECONDS_hypridle=300
    SL_ARGS_SECONDS_swayidle=1800

    local out
    out=$(hb_screen_lock_summary)
    assert_contains "$out" "SUMMARY-MECHANISM: swayidle" "observed arguments win"
    assert_contains "$out" "SUMMARY-RANK: 1" "rank 1"
    assert_contains "$out" "SUMMARY-STATUS: TIMEOUT-TOO-LONG" "and the limit is applied to it"
    reset_sl
}

test_active_desktop_settings_are_authoritative() {
    reset_sl
    SL_ACTIVE_DE="ubuntu:GNOME"; SL_ACTIVE_DE_BASIS="XDG_CURRENT_DESKTOP"
    SL_DE_STATUS_GNOME="ENABLED"; SL_DE_SECONDS_GNOME=300

    local out
    out=$(hb_screen_lock_summary)
    assert_contains "$out" "SUMMARY-MECHANISM: GNOME settings" "GNOME is active"
    assert_contains "$out" "SUMMARY-RANK: 3" "rank 3"
    assert_contains "$out" "SUMMARY-STATUS: ENABLED" "within the limit"
    reset_sl
}

test_settings_of_an_inactive_desktop_are_not_trusted() {
    reset_sl
    SL_DE_STATUS_GNOME="ENABLED"; SL_DE_SECONDS_GNOME=300

    local out
    out=$(hb_screen_lock_summary)
    assert_contains "$out" "SUMMARY-RANK: 4" "recorded as rank 4"
    assert_contains "$out" "SUMMARY-TIMEOUT-SECONDS: undetermined" "its figure is not the enforced timeout"
    assert_contains "$out" "SUMMARY-STATUS: UNDETERMINED" "and it is not relied on"
    reset_sl
}

test_nothing_found_is_recorded_as_none() {
    reset_sl
    local out
    out=$(hb_screen_lock_summary)
    assert_contains "$out" "SUMMARY-MECHANISM: none" "no mechanism"
    assert_contains "$out" "SUMMARY-STATUS: NONE" "status none"
    reset_sl
}

# ------------------------------------------------- screen lock: the verdict

test_screen_lock_verdict_follows_the_summary() {
    setup
    summary_fixture "$WORKDIR/ok" hypridle 2 300 ENABLED
    summary_fixture "$WORKDIR/slow" "GNOME settings" 3 1800 TIMEOUT-TOO-LONG
    summary_fixture "$WORKDIR/unknown" hypridle 1 undetermined UNDETERMINED
    summary_fixture "$WORKDIR/none" none none undetermined NONE

    run_check check_screen_lock_status "$WORKDIR/ok"
    assert_equals 0 "$VERDICT" "established, within the limit"
    assert_equals "Yes (Auto-lock: 5 minutes, hypridle)" "$DETAIL" "names the mechanism"

    run_check check_screen_lock_status "$WORKDIR/slow"
    assert_equals 1 "$VERDICT" "established, above the limit"
    assert_contains "$DETAIL" "30 minutes" "states the timeout"
    assert_contains "$DETAIL" "limit 15 minutes" "and the limit"

    run_check check_screen_lock_status "$WORKDIR/unknown"
    assert_equals 2 "$VERDICT" "enforced, timeout undetermined"
    assert_equals "Auto-lock enforced by hypridle, timeout could not be established" "$DETAIL" "says so"

    run_check check_screen_lock_status "$WORKDIR/none"
    assert_equals 2 "$VERDICT" "no mechanism found"
    teardown
}

test_screen_lock_without_summary_falls_back_and_says_so() {
    setup
    mkdir -p "$WORKDIR/old"
    printf '%s\n' "Total time until auto-lock: 1800 seconds (30 minutes)" \
        "AUTO-LOCK-STATUS: ENABLED" > "$WORKDIR/old/screenlock-info.txt"

    run_check check_screen_lock_status "$WORKDIR/old"
    assert_equals 1 "$VERDICT" "the limit still applies"
    assert_contains "$DETAIL" "source not established" "and the missing provenance is stated"
    teardown
}

# ------------------------------------------------- screen lock: collection

# Run the screen lock collection block of RUNME.sh against stubbed tools.
# Usage: collect_screen_lock <gnome idle-delay seconds> [pgrep stub body]
collect_screen_lock() {
    local bin="$WORKDIR/bin" tool src
    link_real_tools "$bin"
    for tool in head tail wc cut; do
        src=$(command -v "$tool" 2>/dev/null) && ln -sf "$src" "$bin/$tool"
    done
    stub_tool "$bin" pgrep "${2:-exit 1}"
    stub_tool "$bin" gsettings "
case \"\$1 \$3\" in
  'list-schemas ') echo org.gnome.desktop.screensaver ;;
  'get lock-enabled'|'get idle-activation-enabled') echo true ;;
  'get idle-delay') echo 'uint32 $1' ;;
  'get lock-delay') echo 'uint32 0' ;;
esac"
    awk '/# Check for screen lock tools/{f=1} f{print} /\} > "\$output\/screenlock-info.txt"/{if(f) exit}' \
        "$REPO_ROOT/RUNME.sh" > "$WORKDIR/block.sh"
    (
        export PATH="$bin" HOME="$WORKDIR/home"
        unset XDG_CURRENT_DESKTOP
        [[ -n "${COLLECT_SUDO_USER:-}" ]] && export SUDO_USER="$COLLECT_SUDO_USER"
        output="$WORKDIR"
        # shellcheck source=/dev/null
        source "$WORKDIR/block.sh"
    ) >/dev/null 2>&1
}

test_collection_gates_gnome_on_its_own_timeout() {
    setup
    collect_screen_lock 1800
    local evidence
    evidence=$(cat "$WORKDIR/screenlock-info.txt")
    assert_contains "$evidence" "AUTO-LOCK-STATUS: TIMEOUT-TOO-LONG" "GNOME above 900s is marked like the rest"
    [[ "$evidence" != *"AUTO-LOCK-STATUS: ENABLED"* ]]
    assert_success "and not as enabled" $?
    assert_contains "$evidence" "=== Authoritative Source Summary ===" "the summary block is written"
    teardown
}

test_collection_does_not_select_gnome_when_it_is_not_active() {
    setup
    collect_screen_lock 300
    run_check check_screen_lock_status "$WORKDIR"
    assert_equals 2 "$VERDICT" "installed schemas alone do not establish a lock"
    teardown
}

# ------------------------------------------------- hardening threshold

test_hardening_threshold_defaults_to_65_and_reads_the_config() {
    setup
    echo "MIN_HARDENING_SCORE=75" > "$WORKDIR/custom.conf"

    assert_equals 65 "$(unset MIN_HARDENING_SCORE; hb_min_hardening_score)" "unconfigured"
    assert_equals 75 "$(unset MIN_HARDENING_SCORE
        load_server_config "$WORKDIR/custom.conf" >/dev/null; hb_min_hardening_score)" "from the file"
    assert_equals 65 "$(MIN_HARDENING_SCORE=high hb_min_hardening_score 2>/dev/null)" "garbage falls back"
    teardown
}

# A device that passes every control, with a hardening score of 64.
# Usage: compliant_fixture <dir> [screen lock status] [seconds]
compliant_fixture() {
    mkdir -p "$1"
    echo '{"hostname": "host", "hardening_index": "64", "firewall_active": "1", "warning[]": [],
           "package_audit_tool_found": "1", "package_audit_tool": "apt-get",
           "vulnerable_packages_found": "0"}' > "$1/lynis-report.json"
    echo "nvme0n1p2 crypto_LUKS 2" > "$1/blockdevices.txt"
    summary_fixture "$1" hypridle 2 "${3:-300}" "${2:-ENABLED}"
}

# Render the three reports for one output directory.
# Usage: render_reports <dir>   -> sets COMPLIANCE, INVENTORY, XLSX
render_reports() {
    (cd "$WORKDIR" && generate_asset_inventory "$1" >/dev/null \
        && generate_compliance_report "$1" >/dev/null \
        && generate_xlsx_asset_row_report "$1" >/dev/null) 2>/dev/null
    COMPLIANCE=$(cat "$WORKDIR"/honeybadger-*-compliance.md)
    INVENTORY=$(cat "$1/asset-inventory.txt")
    XLSX=$(cat "$WORKDIR"/honeybadger-*-xlsx.md)
}

test_hardening_score_is_informational_and_states_its_threshold() {
    setup
    local dir="$WORKDIR/output-host-user-01-01-2026"
    compliant_fixture "$dir"
    MIN_HARDENING_SCORE=75 render_reports "$dir"

    assert_contains "$COMPLIANCE" "| Hardening score | ℹ️ | 64/100 (drempel >=75) |" "checklist"
    assert_contains "$INVENTORY" "64/100 (Good) - threshold >=75" "inventory"
    assert_contains "$XLSX" "64/100 - threshold >=75 not met" "xlsx"
    [[ "$INVENTORY" != *"COMPLIANT"* ]]
    assert_success "no verdict marker on the score" $?
    assert_contains "$COMPLIANCE" "**Compliance:** ✅ Compliant" "below the threshold, still compliant"
    teardown
}

# ------------------------------------------------- inventory notes

test_inventory_notes_only_explain_what_the_table_shows() {
    setup
    local dir="$WORKDIR/output-host-user-01-01-2026"
    compliant_fixture "$dir"
    printf '%s\n' "PF50L2MR" > "$dir/hardware-serial.txt"
    echo "sysfs:product_serial" > "$dir/hardware-serial-source.txt"
    render_reports "$dir"

    [[ "$INVENTORY" != *"could-not-read"* && "$INVENTORY" != *"none-present"* ]]
    assert_success "a serial that was read gets no serial note" $?
    [[ "$INVENTORY" != *"suspicious software"* && "$INVENTORY" != *"Defender"* ]]
    assert_success "no stale or Windows-only notes" $?
    assert_contains "$INVENTORY" "Antivirus: see the 'Malware Scanner (AV product)' field" "the AV pointer stays"

    printf '%s\n' "none-present" > "$dir/hardware-serial.txt"
    render_reports "$dir"
    assert_contains "$INVENTORY" "Serial Number 'none-present'" "the note appears when the value does"
    [[ "$INVENTORY" != *"could-not-read"* ]]
    assert_success "and only that one" $?
    teardown
}

# ------------------------------------------------- the reports agree

test_all_reports_agree_on_a_screen_lock_above_the_limit() {
    setup
    local dir="$WORKDIR/output-host-user-01-01-2026"
    compliant_fixture "$dir" TIMEOUT-TOO-LONG 1800
    render_reports "$dir"

    assert_contains "$COMPLIANCE" "| Screen lock | ❌ | Timeout too long (30 minutes" "checklist"
    assert_contains "$INVENTORY" "Timeout too long (30 minutes" "inventory"
    assert_contains "$XLSX" "| H   | Screen Lock                    | No " "xlsx cell"
    teardown
}

test_an_old_scan_with_a_long_timeout_is_no_longer_yes_in_the_xlsx() {
    # Before this change the xlsx report matched ENABLED and applied no limit.
    setup
    local dir="$WORKDIR/output-host-user-01-01-2026"
    compliant_fixture "$dir"
    printf '%s\n' "Total time until auto-lock: 1800 seconds (30 minutes)" \
        "AUTO-LOCK-STATUS: ENABLED" > "$dir/screenlock-info.txt"
    render_reports "$dir"

    assert_contains "$XLSX" "| H   | Screen Lock                    | No " "the limit is applied"
    teardown
}

test_an_indeterminate_control_is_na_in_the_xlsx() {
    setup
    local dir="$WORKDIR/output-host-user-01-01-2026"
    compliant_fixture "$dir"
    rm "$dir/blockdevices.txt"
    render_reports "$dir"

    assert_contains "$XLSX" "| G   | Disk Encryption                | N.A. " "not No"
    assert_contains "$XLSX" "- Disk Encryption: Unknown - blockdevices.txt not collected" "listed as unavailable"
    teardown
}


test_gnome_settings_are_read_as_the_invoking_user() {
    setup
    stub_tool "$WORKDIR/bin" getent "echo 'alice:x:1000:100::$WORKDIR/alice:/bin/bash'"
    stub_tool "$WORKDIR/bin" sudo "echo \"\$*\" >> '$WORKDIR/sudo.log'; shift 2; exec \"\$@\""
    ln -sf "$(command -v env)" "$WORKDIR/bin/env"
    COLLECT_SUDO_USER=alice collect_screen_lock 300

    local log
    log=$(cat "$WORKDIR/sudo.log" 2>/dev/null)
    assert_contains "$log" "-u alice env HOME=$WORKDIR/alice gsettings get org.gnome.desktop.session idle-delay" \
        "gsettings runs as alice, with her home"
    assert_contains "$(cat "$WORKDIR/screenlock-info.txt")" "Settings read for user alice" "and the evidence says so"
    teardown
}

test_gnome_settings_read_as_root_say_so() {
    setup
    collect_screen_lock 300
    assert_contains "$(cat "$WORKDIR/screenlock-info.txt")" "(no invoking user known)" "read as root, stated"
    teardown
}

test_a_failed_read_as_the_user_does_not_fall_back_to_root() {
    setup
    stub_tool "$WORKDIR/bin" getent "echo 'alice:x:1000:100::$WORKDIR/alice:/bin/bash'"
    stub_tool "$WORKDIR/bin" sudo 'exit 1'
    COLLECT_SUDO_USER=alice collect_screen_lock 300

    local evidence
    evidence=$(cat "$WORKDIR/screenlock-info.txt")
    assert_contains "$evidence" "GNOME settings could not be read for user alice" "the failure is recorded"
    [[ "$evidence" != *"Idle delay (seconds)"* ]]
    assert_success "and root's values are not reported instead" $?
    teardown
}

test_collection_reads_lock_config_from_the_invoking_users_home() {
    # Under sudo $HOME is root's. The hypridle config the user wrote lives in
    # their own home, and that is where the verdict has to come from.
    setup
    mkdir -p "$WORKDIR/alice/.config/hypr" "$WORKDIR/home"
    echo "    timeout = 300" > "$WORKDIR/alice/.config/hypr/hypridle.conf"
    stub_tool "$WORKDIR/bin" getent "echo 'alice:x:1000:100::$WORKDIR/alice:/bin/bash'"
    COLLECT_SUDO_USER=alice collect_screen_lock 300 \
        '[ "$1" = "-af" ] && echo "123 /nix/store/x-hypridle-0.1.7/bin/hypridle" || exit 1'

    run_check check_screen_lock_status "$WORKDIR"
    assert_equals 0 "$VERDICT" "the user's own config establishes the timeout"
    assert_equals "Yes (Auto-lock: 5 minutes, hypridle)" "$DETAIL" "from the running daemon"
    teardown
}

run_tests "$@"
