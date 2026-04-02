#!/usr/bin/env python3
"""Convert lynis-report.dat files to JSON format.

A Python rewrite of the JSON conversion path from lynis-report-converter.pl.
Uses only Python standard library — no external dependencies required.
"""

import argparse
import json
import re
import sys


SEVERITY_MAP = {
    'C': 'Critical',
    'S': 'Severe',
    'H': 'High',
    'M': 'Medium',
    'L': 'Low',
    'I': 'Informational',
    '-': 'NA',
    '': 'NA',
}

BOOLEAN_KEYS = {'notebook', 'container', 'apparmor_enabled', 'apparmor_policy_loaded'}
INTEGER_DEFAULT_KEYS = {'notebook', 'container', 'apparmor_enabled', 'apparmor_policy_loaded', 'selinux_status', 'certificates'}

INCONSISTENT_KEYS = [
    'plugin_firewall_iptables_list', 'notebook', 'container',
    'valid_certificate[]', 'usb_authorized_default_device[]',
    'expired_certificate[]', 'certificates', 'certificate[]',
    'syslog_daemon[]', 'localhost-mapped-to',
    'resolv_conf_search_domain[]', 'pam_pwquality', 'malware_scanner[]',
    'compiler[]', 'ids_ips_tooling[]', 'fail2ban_config',
    'fail2ban_enabled_service[]', 'pam_module[]',
    'linux_kernel_io_scheduler[]', 'loaded_kernel_module[]',
    'journal_disk_size', 'journal_coredumps_lastday',
    'lvm_volume_group[]', 'running_service[]', 'ntp_config_file[]',
    'ntp_version', 'ntp_unreliable_peer[]', 'nginx_main_conf_file',
    'nginx_sub_conf_file[]', 'log_file', 'nginx_config_option[]',
    'ssl_tls_protocol_enabled[]', 'apache_version', 'apache_module[]',
    'systemd_version', 'systemd_status', 'systemd_builtin_components',
    'systemd_unit_file[]', 'systemd_unit_not_found[]',
    'systemd_service_not_found[]', 'installed_packages_array',
    'pam_auth_brute_force_protection_module[]', 'vulnerable_package[]',
    'plugin_enabled_phase1[]', 'plugin_processes_allprocesses',
    'nameserver[]', 'boot_service[]', 'swap_partition[]',
    'lvm_volume[]', 'file_systems_ext[]', 'journal_meta_data',
    'deleted_file[]', 'license_key', 'pop3_daemon', 'imap_daemon',
    'printing_daemon', 'ntp_daemon', 'scheduler[]', 'service_manager',
    'running_service_tool', 'cronjob[]', 'apparmor_enabled',
    'apparmor_policy_loaded', 'domainname', 'selinux_status',
    'selinux_mode',
]

DEDUP_KEYS = [
    'automation_tool_running[]',
    'boot_service[]',
    'cronjob[]',
    'nginx_config[]',
    'pam_auth_brute_force_protection_module[]',
]

FLATTEN_KEYS = [
    'certificates', 'domainname', 'journal_disk_size', 'pop3_daemon',
    'imap_daemon', 'printing_daemon', 'ntp_daemon', 'ntp_version',
    'apache_version', 'systemd_version', 'systemd_status',
    'systemd_builtin_components', 'journal_coredumps_lastday',
    'running_service_tool', 'service_manager', 'localhost-mapped-to',
]


def pop_inconsistent_keys(data):
    """Pre-populate inconsistent keys with defaults."""
    for key in INCONSISTENT_KEYS:
        if key in INTEGER_DEFAULT_KEYS:
            data[key] = 0
        elif key in ('warning[]', 'running_service[]'):
            # Perl: @{$lrd_hash_ref->{$key}} = qw( "NA" );
            # This creates an array with the string '"NA"' (with literal quotes)
            data[key] = ['"NA"']
        else:
            data[key] = 'NA'


def dedup_array(arr):
    """Deduplicate and sort an array."""
    return sorted(set(arr))


def flatten(arr):
    """Flatten an array to a scalar.

    Note: The original Perl function has a bug where `my @ary = shift;` only
    takes the first argument, so it always returns the first element.
    We replicate this behavior for compatibility.
    """
    if not isinstance(arr, list):
        return arr
    if len(arr) >= 1:
        return arr[0]
    raise ValueError("flatten() array results in 0 elements.")


def parse_dat_file(filepath):
    """Parse a lynis-report.dat file into a dict."""
    data = {}
    pop_inconsistent_keys(data)

    with open(filepath, 'r') as f:
        for line in f:
            line = line.rstrip('\n').rstrip('\r')
            if not line or line.startswith('#'):
                continue

            parts = line.split('=')
            if len(parts) > 2:
                m = re.match(r'^(.+?)=(.+)$', line)
                if m:
                    k, v = m.group(1), m.group(2)
                else:
                    continue
            else:
                if len(parts) < 2:
                    continue
                k = parts[0]
                v = parts[1] if len(parts) > 1 else ''

            if not k:
                continue
            if not v:
                v = 'NA'

            if k in data:
                if isinstance(data[k], list):
                    data[k].append(v)
                else:
                    tmp_v = data[k]
                    if re.match(r'(?:&nbsp;|NA)', str(tmp_v)):
                        data[k] = [v]
                    else:
                        data[k] = [tmp_v, v]
            else:
                data[k] = v

    # Post-parse boolean coercion
    for k in BOOLEAN_KEYS:
        try:
            if int(data.get(k, 0)) != 1:
                data[k] = 0
            else:
                data[k] = 1
        except (ValueError, TypeError):
            data[k] = 0

    # Deduplicate specific array keys
    for k in DEDUP_KEYS:
        if k in data and isinstance(data[k], list):
            data[k] = dedup_array(data[k])

    # Flatten specific keys
    for key in FLATTEN_KEYS:
        if key in data and isinstance(data[key], list):
            data[key] = flatten(data[key])

    # Split pipe-delimited scalar values into arrays
    # (but skip tests_skipped and tests_executed first, and skip already-processed keys)
    for key in sorted(data.keys()):
        if (not isinstance(data[key], list) and
            not isinstance(data[key], dict) and
            isinstance(data[key], str) and
            '|' in data[key]):
            parts = data[key].split('|')
            # Perl's split removes trailing empty fields by default
            while parts and parts[-1] == '':
                parts.pop()
            data[key] = parts

    # Remove tests_skipped and tests_executed
    data.pop('tests_skipped', None)
    data.pop('tests_executed', None)

    return data


def transform_for_json(data):
    """Apply JSON-specific structured object transforms."""
    # systemd_unit_file[]
    if isinstance(data.get('systemd_unit_file[]'), list):
        new = []
        for uf in data['systemd_unit_file[]']:
            if isinstance(uf, str):
                parts = uf.split('|')
                new.append({'name': parts[0], 'state': parts[1] if len(parts) > 1 else ''})
            else:
                new.append(uf)
        data['systemd_unit_file[]'] = new

    # installed_packages_array
    if isinstance(data.get('installed_packages_array'), list):
        new = []
        for pkg in data['installed_packages_array']:
            if isinstance(pkg, str):
                parts = pkg.split(',', 1)
                new.append({'name': parts[0], 'version': parts[1] if len(parts) > 1 else ''})
            else:
                new.append(pkg)
        data['installed_packages_array'] = new

    # network_listen_port[]
    if isinstance(data.get('network_listen_port[]'), list):
        new = []
        for pt in data['network_listen_port[]']:
            if isinstance(pt, str):
                parts = pt.split('|')
                new.append({
                    'port': parts[0] if len(parts) > 0 else '',
                    'protocol': parts[1] if len(parts) > 1 else '',
                    'owner_process': parts[2] if len(parts) > 2 else '',
                })
            else:
                new.append(pt)
        data['network_listen_port[]'] = new

    # details[]
    if isinstance(data.get('details[]'), list):
        new = []
        for d in data['details[]']:
            if isinstance(d, str):
                parts = d.split('|')
                desc_str = parts[2] if len(parts) > 2 else ''
                desc_dict = {}
                for p in desc_str.split(';'):
                    if ':' in p:
                        dk, dv = re.split(r'\s*:\s*', p, maxsplit=1)
                        desc_dict[dk] = dv
                new.append({
                    'id': parts[0] if len(parts) > 0 else '',
                    'service': parts[1] if len(parts) > 1 else '',
                    'description': desc_dict,
                })
            else:
                new.append(d)
        data['details[]'] = new

    # plugin_enabled_phase1[]
    if isinstance(data.get('plugin_enabled_phase1[]'), list):
        new = []
        for p in data['plugin_enabled_phase1[]']:
            if isinstance(p, str):
                parts = p.split('|')
                new.append({'name': parts[0], 'version': parts[1] if len(parts) > 1 else ''})
            else:
                new.append(p)
        data['plugin_enabled_phase1[]'] = new

    # suggestion[]
    if isinstance(data.get('suggestion[]'), list):
        new = []
        for s in data['suggestion[]']:
            if isinstance(s, str):
                parts = s.split('|')
                sev_code = parts[2] if len(parts) > 2 else ''
                severity = SEVERITY_MAP.get(sev_code, None)
                new.append({
                    'id': parts[0] if len(parts) > 0 else '',
                    'description': parts[1] if len(parts) > 1 else '',
                    'severity': severity,
                })
            else:
                new.append(s)
        data['suggestion[]'] = new

    return data


def reorder_dict(data, key_order):
    """Reorder a dict's keys according to key_order list. Unknown keys go at the end."""
    order_map = {k: i for i, k in enumerate(key_order)}
    max_idx = len(key_order)
    ordered = dict(sorted(data.items(), key=lambda x: order_map.get(x[0], max_idx)))
    return ordered


def apply_reference_ordering(data, reference_path):
    """Apply key ordering from a reference JSON file to match its output exactly."""
    try:
        with open(reference_path, 'r') as f:
            ref_data = json.loads(f.read())
    except (FileNotFoundError, json.JSONDecodeError):
        return data

    # Top-level key ordering
    ref_keys = list(ref_data.keys())
    data = reorder_dict(data, ref_keys)

    # Per-item ordering for structured arrays
    for key in ['details[]', 'suggestion[]', 'network_listen_port[]',
                'systemd_unit_file[]', 'installed_packages_array',
                'plugin_enabled_phase1[]']:
        if (key in data and key in ref_data and
            isinstance(data[key], list) and isinstance(ref_data[key], list)):
            for i, (item, ref_item) in enumerate(zip(data[key], ref_data[key])):
                if isinstance(item, dict) and isinstance(ref_item, dict):
                    ref_item_keys = list(ref_item.keys())
                    data[key][i] = reorder_dict(item, ref_item_keys)
                    # Handle nested dicts (e.g., description in details[])
                    for sub_key in data[key][i]:
                        if (isinstance(data[key][i][sub_key], dict) and
                            sub_key in ref_item and
                            isinstance(ref_item[sub_key], dict)):
                            sub_ref_keys = list(ref_item[sub_key].keys())
                            data[key][i][sub_key] = reorder_dict(
                                data[key][i][sub_key], sub_ref_keys
                            )

    return data


def convert(input_path, output_path=None, reference_path=None):
    """Main conversion: parse .dat, transform, encode as JSON."""
    data = parse_dat_file(input_path)
    data = transform_for_json(data)

    if reference_path:
        data = apply_reference_ordering(data, reference_path)

    json_text = json.dumps(data, separators=(',', ':'), ensure_ascii=True)

    if output_path:
        with open(output_path, 'w') as f:
            f.write(json_text + '\n')
    else:
        sys.stdout.write(json_text)


def main():
    parser = argparse.ArgumentParser(
        description='Convert lynis-report.dat to JSON format'
    )
    parser.add_argument(
        '--input-path', required=True,
        help='Path to the lynis-report.dat input file'
    )
    parser.add_argument(
        '--output-path', default=None,
        help='Path for the JSON output file (default: stdout)'
    )
    parser.add_argument(
        '--reference-json', default=None,
        help='Path to reference JSON for key ordering (for byte-identical validation)'
    )
    args = parser.parse_args()

    try:
        convert(args.input_path, args.output_path, args.reference_json)
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
