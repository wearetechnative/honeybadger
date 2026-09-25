#!/usr/bin/env bash
#(C)2019-2022 Pim Snel - https://github.com/mipmip/RUNME.sh
CMDS=();DESC=();NARGS=$#;ARG1=$1;shift;ARGS="$@";make_command(){ CMDS+=($1);DESC+=("$2");};usage(){ printf "\nUsage: %s [command]\n\nCommands:\n" $0;line="              ";for((i=0;i<=$(( ${#CMDS[*]} -1));i++));do printf "  %s %s ${DESC[$i]}\n" ${CMDS[$i]} "${line:${#CMDS[$i]}}";done;echo;};runme(){ if test $NARGS -ge 1;then eval "$ARG1 $ARGS"||usage;else usage;fi;}

##### LOAD LIBRARIES #####

thisdir="$(dirname "$0")"

# Load library file
if [[ -f "$thisdir/lib/_library" ]]; then
    source "$thisdir/lib/_library"
fi

##### PLACE YOUR COMMANDS BELOW #####

MISSING_DEPS=()

function show_version(){
  version=`cat $thisdir/VERSION-honeybadger`
  echo
  echo "    Honeybadger v${version}"
  echo "    a Personal Device Audit tool for ISO27001"
  echo
  echo "    Make your computer as tough as a honeybadger"
  echo
  echo "    http://github.com/wearetechnative/personal-device-audit"
  echo
  echo "    by Pim, Wouter et al."
  echo "    © Technative 2024"
  echo
}

function checkdeps(){
  if ! command -v $1 &> /dev/null
  then
    MISSING_DEPS+=("$1")
    echo "<$1> could not be found"
    echo "  Install this program first"
    if [ -n "$2" ]; then
      echo "  Check this site for more info: $2"
    fi
  fi
}

function deps_missing(){
  if [ ${#MISSING_DEPS[@]} -gt 0 ]
  then
    exit 1
  fi
}

function checkOS {
  if [[ $(uname -o)  == *"Linux"* ]]; then
    osType="linux"
  elif [[ $(uname -o) == *"Darwin"* ]]; then
    osType="macos"
  else
    osType="unknown"
    echo "!!! System not Linux Macos, can't determine checkBlockDevices"
  fi


}

function checkBlockDevices {
  if [[ ${osType} == "linux" ]]; then
    lsblk -fs
  elif [[ ${osType} == "macos" ]]; then
    diskutil list
    fdesetup status
  else
    echo "!! Unable to check Block Devices, unknown ostype"
  fi

}



make_command "audit" "Run Audit Tool to create report"
audit(){
 set -e  # Exit on error

 # Check if running as root
 if [[ $EUID -ne 0 ]]; then
   echo "ERROR: Audit requires root privileges"
   echo "Please run with sudo:"
   echo "  sudo ./RUNME.sh audit"
   exit 1
 fi

 show_version
 checkOS
 load_server_config
 checkdeps "lynis" "https://github.com/CISOfy/lynis"
 if [[ "$USE_DOCKER_CONVERTER" == "true" ]]; then
   checkdeps "docker"
 else
   checkdeps "python3"
 fi
 checkdeps "sed"
 checkdeps "fastfetch"
 checkdeps "tar"
 checkdeps "jq"
 checkdeps "curl"

 deps_missing

 # Use SUDO_USER if running with sudo, otherwise use current user
 local actual_user="${SUDO_USER:-$(whoami)}"

 # Declared and assigned separately on purpose: `local x=$(cmd)` returns the
 # builtin's exit status, not the command's, so a failing resolver would be
 # invisible and the run would name its output with an empty hostname.
 local hostname
 if ! hostname=$(hb_resolve_short_hostname); then
   echo "ERROR: could not determine this machine's hostname" >&2
   echo "  Tried: uname -n, \$HOSTNAME, /etc/hostname" >&2
   echo "  The hostname names the output directory and the tar archive," >&2
   echo "  so the audit stops rather than producing output without one." >&2
   exit 1
 fi

 output=output-${hostname}-${actual_user}-$(date +"%d-%m-%Y")
 tarball=honeybadger-${hostname}-${actual_user}-$(date +"%d-%m-%Y").tar.gz
 mkdir -p $output

 echo "Running Lynis audit..."
 lynis audit system || { echo "ERROR: Lynis audit failed"; exit 1; }

 # Convert Lynis report to JSON
 echo "Converting Lynis report to JSON..."
 if [[ "$USE_DOCKER_CONVERTER" == "true" ]]; then
   # Docker-based Perl converter (legacy)
   local image_name="wearetechnative/lynis-report-converter:latest"

   # Stamp the Dockerfile's checksum into the image so staleness is decided by
   # content, not by mtime (a fresh clone rewrites mtimes without changing anything).
   local dockerfile_sha=""
   if command -v sha256sum >/dev/null 2>&1; then
     dockerfile_sha=$(sha256sum Dockerfile | cut -d' ' -f1)
   elif command -v shasum >/dev/null 2>&1; then
     dockerfile_sha=$(shasum -a 256 Dockerfile | cut -d' ' -f1)
   fi
   local image_sha
   image_sha=$(docker image inspect --format '{{index .Config.Labels "hb.dockerfile.sha"}}' "$image_name" 2>/dev/null)

   if ! docker image inspect "$image_name" >/dev/null 2>&1; then
     echo "Building Docker image (first time)..."
     docker build -t "$image_name" --label "hb.dockerfile.sha=$dockerfile_sha" . || { echo "ERROR: Docker build failed"; exit 1; }
   elif [ -f Dockerfile ] && [ -n "$dockerfile_sha" ] && [ "$image_sha" != "$dockerfile_sha" ]; then
     echo "Dockerfile changed, rebuilding image..."
     docker build -t "$image_name" --label "hb.dockerfile.sha=$dockerfile_sha" . || { echo "ERROR: Docker build failed"; exit 1; }
   else
     echo "Using cached Docker image"
   fi

   docker run --rm \
     --read-only \
     -v /var/log/lynis-report.dat:/data/lynis-report.dat:ro \
     "$image_name" 2>/dev/null > $output/lynis-report.json || { echo "ERROR: Report conversion failed"; exit 1; }
 else
   # Python converter (default)
   python3 "$thisdir/lib/lynis_report_converter.py" \
     --input-path /var/log/lynis-report.dat \
     --output-path "$output/lynis-report.json" || { echo "ERROR: Report conversion failed"; exit 1; }
 fi
 # Run fastfetch as actual user (not root) to capture correct username
 sudo -u "${SUDO_USER:-$(whoami)}" fastfetch \
   --config "$thisdir/lib/fastfetch-config.jsonc" \
   --logo none \
   | jq -Rn '
   ([inputs | select(length>0)] |
    (.[0] | capture("^(?<user>[^@]+)@(?<hostname>\\S+)") // {}) +
    (.[1:] | map(select(contains(":"))) | map(capture("(?<key>[^:]+): (?<value>.*)")) | map({(.key|ascii_downcase|gsub(" "; "_")): .value}) | add // {})
   )' > "$output/fastfetch.json"
 command -v lsb_release >/dev/null && lsb_release -a > "$output/lsb_release.txt"
 show_version > $output/honeybadger-info.txt
 checkBlockDevices > $output/blockdevices.txt

 # Collect hardware serial number (requires root, which audit already checked).
 # The kernel is the primary source, so this does not depend on dmidecode being
 # installed - which is exactly why half the fleet never reported a serial.
 echo "Collecting hardware serial number..."
 if collect_hardware_serial "$output"; then
   echo "  Found $HB_SERIAL_VALUE via $HB_SERIAL_SOURCE"
 else
   echo "  No usable serial yet ($HB_SERIAL_STATUS) - details at the end of the run"
 fi

 # Collect installed packages information
 echo "Collecting package information..."
 if command -v dpkg >/dev/null 2>&1; then
   # Debian/Ubuntu
   dpkg -l > "$output/installed-packages.txt"
 elif command -v rpm >/dev/null 2>&1; then
   # RHEL/Fedora/CentOS
   rpm -qa > "$output/installed-packages.txt"
 elif command -v pacman >/dev/null 2>&1; then
   # Arch Linux
   pacman -Q > "$output/installed-packages.txt"
 elif command -v nix >/dev/null 2>&1; then
   # NixOS - handle both traditional nix-env and modern flakes-based profiles
   {
     echo "=== NixOS Package Information ==="
     echo "Note: Full package listing may not be available due to Nix profile compatibility"
     echo ""

     # Show NixOS version and channel info
     if [ -f /etc/os-release ]; then
       echo "OS Information:"
       grep -E "^(NAME|VERSION|VERSION_ID)" /etc/os-release 2>/dev/null || true
       echo ""
     fi

     # Try to get some basic package info without using incompatible commands
     echo "Basic system information:"
     echo "Nix version: $(nix --version 2>/dev/null || echo 'unknown')"

     # Count packages in system profile
     if [ -e /nix/var/nix/profiles/system/sw/bin ]; then
       pkg_count=$(ls /nix/var/nix/profiles/system/sw/bin 2>/dev/null | wc -l)
       echo "Approximate system binaries: $pkg_count"
     fi

     # Try user profile with modern nix profile (suppress incompatibility errors)
     echo ""
     echo "User profile check:"
     if nix profile list >/dev/null 2>&1; then
       echo "User packages (nix profile):"
       nix profile list 2>/dev/null | head -20 || echo "nix profile list returned empty"
     else
       # Fallback to traditional nix-env but catch the incompatibility error
       if command -v nix-env >/dev/null 2>&1; then
         echo "Checking user environment (nix-env may show compatibility warning):"
         nix-env -q 2>&1 | grep -v "is incompatible" | head -20 || echo "User profile: using flakes or modern nix profile"
       fi
     fi
   } > "$output/installed-packages.txt" 2>&1
 fi

 # Collect NixOS-specific metadata (if running on NixOS)
 if command -v nixos-version >/dev/null 2>&1 || [[ -f /etc/os-release && $(grep -c "^ID=nixos" /etc/os-release 2>/dev/null) -gt 0 ]]; then
   echo "Collecting NixOS system metadata..."
   {
     echo "=== NixOS System Information ==="
     echo "Collection Date: $(date)"
     echo ""

     # Get NixOS version and commit hash
     if command -v nixos-version >/dev/null 2>&1; then
       echo "NixOS Version:"
       nixos-version 2>/dev/null || echo "Unable to retrieve version"
       echo ""

       if nixos-version --json >/dev/null 2>&1; then
         echo "Detailed Version Info (JSON):"
         nixos-version --json 2>/dev/null || echo "JSON format not available"
         echo ""
       fi
     fi

     # Fallback: read version file
     if [[ -f /run/current-system/nixos-version ]]; then
       echo "System Version File:"
       cat /run/current-system/nixos-version 2>/dev/null
       echo ""
     fi

     # Get current system generation
     if [[ -L /nix/var/nix/profiles/system ]]; then
       echo "Current System Generation:"
       readlink /nix/var/nix/profiles/system 2>/dev/null || echo "Unable to read"
       echo ""
     fi

     # Get last rebuild date
     if [[ -L /nix/var/nix/profiles/system ]]; then
       echo "Last System Rebuild:"
       stat -c "Date: %y" /nix/var/nix/profiles/system 2>/dev/null || stat -f "Date: %Sm" /nix/var/nix/profiles/system 2>/dev/null || echo "Unable to determine"
       echo ""
     fi

     # List recent generations
     if command -v nixos-rebuild >/dev/null 2>&1; then
       echo "Recent System Generations (last 5):"
       nixos-rebuild list-generations 2>/dev/null | tail -5 || echo "Unable to list generations"
       echo ""
     fi

     echo "=== End of NixOS System Information ==="
   } > "$output/nixos-system-info.txt" 2>&1

   # Run NixOS supply chain security audit
   echo "Running NixOS supply chain security audit..."
   if [[ -x "$thisdir/lib/PKGS-7398-nix-audit.sh" ]]; then
     # Execute as actual user (not root) to read correct Nix config
     if sudo -u "${SUDO_USER:-$(whoami)}" "$thisdir/lib/PKGS-7398-nix-audit.sh" > "$output/nix-supply-chain-audit.txt" 2>&1; then
       echo "  ✅ NixOS supply chain audit completed"
     else
       echo "  ⚠️  NixOS supply chain audit failed (non-critical, continuing)"
     fi
   else
     echo "  ⚠️  lib/PKGS-7398-nix-audit.sh not found or not executable"
   fi
 fi

 # Check for screen lock tools
 echo "Checking screen lock tools..."
 # What each mechanism established, for the summary block written at the end.
 # hb_screen_lock_summary documents every SL_* variable.
 unset "${!SL_@}"
 SL_RUNNING=""
 # The audit runs as root, but the lock is configured by the user who ran it.
 # Under sudo $HOME is root's home, where no hypridle or sway config lives.
 sl_user="${SUDO_USER:-$(id -un)}"
 sl_home=$(getent passwd "$sl_user" 2>/dev/null | cut -d: -f6)
 sl_home="${sl_home:-$HOME}"
 # GNOME's settings are the user's too. Read as root, gsettings returns root's
 # settings or the schema defaults, so it runs as the invoking user.
 sl_settings_user=""
 if [[ -n "$sl_user" && "$sl_user" != "$(id -un 2>/dev/null)" ]]; then
   sl_settings_user="$sl_user"
 fi
 sl_gsettings() {
   if [[ -n "$sl_settings_user" ]]; then
     local uid bus=""
     uid=$(id -u "$sl_settings_user" 2>/dev/null) || uid=""
     if [[ -n "$uid" && -S "/run/user/$uid/bus" ]]; then
       bus="unix:path=/run/user/$uid/bus"
     fi
     sudo -u "$sl_settings_user" env HOME="$sl_home" ${bus:+DBUS_SESSION_BUS_ADDRESS=$bus} gsettings "$@"
   else
     gsettings "$@"
   fi
 }
 if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
   SL_ACTIVE_DE="$XDG_CURRENT_DESKTOP"
   SL_ACTIVE_DE_BASIS="XDG_CURRENT_DESKTOP"
 elif command -v pgrep >/dev/null 2>&1; then
   # The audit runs under sudo, which clears XDG_CURRENT_DESKTOP. The session
   # process that is running says the same thing, and is observed rather than
   # stated.
   for _de_proc in gnome-shell:GNOME plasmashell:KDE xfce4-session:XFCE Hyprland:Hyprland start-hyprland:Hyprland sway:sway; do
     if pgrep -x "${_de_proc%%:*}" >/dev/null 2>&1; then
       SL_ACTIVE_DE="${_de_proc#*:}"
       SL_ACTIVE_DE_BASIS="${_de_proc%%:*} running"
       break
     fi
   done
 fi
 # The SL_* variables set below are read by hb_screen_lock_summary through
 # indirect expansion, which shellcheck cannot follow.
 # shellcheck disable=SC2034
 {
   echo "=== Screen Lock Tools Detection ==="
   for tool in swaylock hyprlock gnome-screensaver xscreensaver i3lock slock light-locker xfce4-screensaver; do
     if command -v "$tool" >/dev/null 2>&1; then
       echo "FOUND: $tool - $(command -v $tool)"
     fi
   done
   echo ""

   echo "=== Desktop Environment Detection ==="
   echo "XDG_CURRENT_DESKTOP: ${XDG_CURRENT_DESKTOP:-Not set}"
   echo "XDG_SESSION_TYPE: ${XDG_SESSION_TYPE:-Not set}"
   echo "DESKTOP_SESSION: ${DESKTOP_SESSION:-Not set}"
   echo ""

   echo "=== GNOME Settings (if available) ==="
   if [[ -n "$sl_settings_user" ]]; then
     echo "Settings read for user $sl_settings_user"
   else
     echo "Settings read as $(id -un 2>/dev/null || echo root) (no invoking user known)"
   fi
   gnome_schemas=""
   gnome_readable=true
   lock_enabled=""
   if ! command -v gsettings >/dev/null 2>&1; then
     echo "gsettings command not found"
   elif ! gnome_schemas=$(sl_gsettings list-schemas 2>/dev/null); then
     gnome_readable=false
   fi
   if [[ "$gnome_readable" == true && -n "$gnome_schemas" ]] \
      && ! echo "$gnome_schemas" | grep -q "org.gnome.desktop.screensaver"; then
     echo "GNOME screensaver settings not available"
   elif [[ "$gnome_readable" == true && -n "$gnome_schemas" ]]; then
       lock_enabled=$(sl_gsettings get org.gnome.desktop.screensaver lock-enabled 2>/dev/null || echo "unknown")
       idle_activation=$(sl_gsettings get org.gnome.desktop.screensaver idle-activation-enabled 2>/dev/null || echo "unknown")
       idle_delay=$(sl_gsettings get org.gnome.desktop.session idle-delay 2>/dev/null || echo "unknown")
       lock_delay=$(sl_gsettings get org.gnome.desktop.screensaver lock-delay 2>/dev/null || echo "unknown")
       # A read that failed is not a setting. Root's values are the defaults,
       # so there is nothing to fall back to.
       if [ "$lock_enabled" = "unknown" ] || [ "$idle_activation" = "unknown" ]; then
         gnome_readable=false
       fi
   fi
   if [[ "$gnome_readable" != true ]]; then
     echo "GNOME settings could not be read for user ${sl_settings_user:-root}"
   elif [[ -n "${lock_enabled:-}" ]]; then
       echo "Lock enabled: $lock_enabled"
       echo "Idle activation: $idle_activation"
       echo "Idle delay (seconds): $idle_delay"
       echo "Lock delay after screensaver: $lock_delay"

       # Calculate total time until auto-lock
       if [ "$idle_delay" != "unknown" ] && [ "$lock_delay" != "unknown" ]; then
         # Remove "uint32 " prefix if present and get only the last number
         idle_val=$(echo "$idle_delay" | grep -oP '\d+' | tail -1 || echo "0")
         lock_val=$(echo "$lock_delay" | grep -oP '\d+' | tail -1 || echo "0")
         # Ensure we have valid numbers
         idle_val=${idle_val:-0}
         lock_val=${lock_val:-0}
         total_delay=$((idle_val + lock_val))
         echo "Total time until auto-lock: ${total_delay} seconds ($(($total_delay / 60)) minutes)"
       fi

       # Check if auto-lock is properly configured. GNOME is gated on its own
       # timeout like every other mechanism; an idle delay of 0 means never.
       if [ "$lock_enabled" = "true" ] && [ "$idle_activation" = "true" ]; then
         if [ -n "${total_delay:-}" ] && [ "${idle_val:-0}" -eq 0 ]; then
           echo "AUTO-LOCK-STATUS: DISABLED (idle delay 0: never)"
           SL_DE_STATUS_GNOME="DISABLED"
         elif [ -n "${total_delay:-}" ] && [ "$total_delay" -gt 900 ]; then
           echo "AUTO-LOCK-STATUS: TIMEOUT-TOO-LONG (>${total_delay}s)"
           SL_DE_STATUS_GNOME="ENABLED"; SL_DE_SECONDS_GNOME="$total_delay"
         else
           echo "AUTO-LOCK-STATUS: ENABLED"
           SL_DE_STATUS_GNOME="ENABLED"; SL_DE_SECONDS_GNOME="${total_delay:-}"
         fi
       else
         echo "AUTO-LOCK-STATUS: DISABLED"
         SL_DE_STATUS_GNOME="DISABLED"
       fi
   fi
   echo ""

   echo "=== Hyprland/Sway Config Check ==="
   echo "Config read for user $sl_user from $sl_home"
   # Check Hyprland
   if [ -f "$sl_home/.config/hypr/hyprland.conf" ]; then
     echo "Hyprland config found at $sl_home/.config/hypr/hyprland.conf"
     grep -i "lock\|swaylock\|hyprlock" "$sl_home/.config/hypr/hyprland.conf" 2>/dev/null || echo "No lock configuration found"
   fi

   # Check Sway
   if [ -f "$sl_home/.config/sway/config" ]; then
     echo "Sway config found at $sl_home/.config/sway/config"
     grep -i "lock\|swaylock" "$sl_home/.config/sway/config" 2>/dev/null || echo "No lock configuration found"
   fi

   # Check hypridle config for auto-lock timeout
   if [ -f "$sl_home/.config/hypr/hypridle.conf" ]; then
     echo ""
     echo "Hypridle config found at $sl_home/.config/hypr/hypridle.conf"
     # Look for timeout settings
     timeout_line=$(grep -E "timeout.*=.*[0-9]+" "$sl_home/.config/hypr/hypridle.conf" 2>/dev/null | head -1)
     if [ -n "$timeout_line" ]; then
       echo "$timeout_line"
       timeout_value=$(echo "$timeout_line" | grep -oP '\d+' | head -1)
       if [ -n "$timeout_value" ]; then
         echo "Auto-lock timeout: ${timeout_value} seconds ($(($timeout_value / 60)) minutes)"
         SL_CONF_SECONDS_hypridle="$timeout_value"
         SL_CONF_SOURCE_hypridle="$sl_home/.config/hypr/hypridle.conf"
         if [ "$timeout_value" -le 900 ]; then
           echo "AUTO-LOCK-STATUS: ENABLED (timeout ≤15 min)"
         else
           echo "AUTO-LOCK-STATUS: TIMEOUT-TOO-LONG (>${timeout_value}s)"
         fi
       fi
     else
       echo "No timeout configuration found"
     fi
   fi

   # Check swayidle config
   if command -v swayidle >/dev/null 2>&1; then
     if [ -f "$sl_home/.config/sway/config" ]; then
       echo ""
       echo "Checking swayidle configuration in Sway config..."
       swayidle_config=$(grep -A2 "exec.*swayidle" "$sl_home/.config/sway/config" 2>/dev/null)
       if [ -n "$swayidle_config" ]; then
         echo "$swayidle_config"
         timeout_val=$(echo "$swayidle_config" | grep -oP 'timeout \K\d+' | head -1)
         if [ -n "$timeout_val" ]; then
           echo "Auto-lock timeout: ${timeout_val} seconds ($(($timeout_val / 60)) minutes)"
           SL_CONF_SECONDS_swayidle="$timeout_val"
           SL_CONF_SOURCE_swayidle="$sl_home/.config/sway/config"
           if [ "$timeout_val" -le 900 ]; then
             echo "AUTO-LOCK-STATUS: ENABLED (timeout ≤15 min)"
           else
             echo "AUTO-LOCK-STATUS: TIMEOUT-TOO-LONG (>${timeout_val}s)"
           fi
         fi
       fi
     fi
   fi
   echo ""

   echo "=== Auto-lock Daemons ==="
   for daemon in swayidle hypridle xss-lock xautolock; do
     if command -v "$daemon" >/dev/null 2>&1; then
       echo "FOUND: $daemon - $(command -v $daemon)"
     fi
   done

   # Check if processes are running and extract timeout info
   if command -v pgrep >/dev/null 2>&1; then
     echo ""
     echo "=== Running Lock-related Processes ==="
     running_procs=$(pgrep -af "swayidle|hypridle|xss-lock|xautolock|gnome-screensaver" 2>/dev/null)
     if [ -n "$running_procs" ]; then
       echo "$running_procs"

       for _daemon in hypridle swayidle xautolock xss-lock gnome-screensaver; do
         if echo "$running_procs" | grep -qE "(^[0-9]+ |/)${_daemon}( |$)"; then
           SL_RUNNING="${SL_RUNNING:+$SL_RUNNING }$_daemon"
         fi
       done
       # swayidle carries its timeout on its command line
       _swayidle_args=$(echo "$running_procs" | grep -E "(^[0-9]+ |/)swayidle( |$)" | grep -oP 'timeout \K\d+' | head -1)
       [ -n "$_swayidle_args" ] && SL_ARGS_SECONDS_swayidle="$_swayidle_args"
       # gnome-screensaver reads its timeout from the GNOME settings above
       if [ -n "${SL_DE_SECONDS_GNOME:-}" ]; then
         SL_CONF_SECONDS_gnome_screensaver="$SL_DE_SECONDS_GNOME"
         SL_CONF_SOURCE_gnome_screensaver="GNOME settings"
       fi

       # Try to extract xautolock timeout if running
       if echo "$running_procs" | grep -q "xautolock"; then
         xautolock_time=$(echo "$running_procs" | grep "xautolock" | grep -oP '\-time \K\d+')
         if [ -n "$xautolock_time" ]; then
           echo "xautolock timeout: ${xautolock_time} minutes"
           SL_ARGS_SECONDS_xautolock=$((xautolock_time * 60))
           if [ "$xautolock_time" -le 15 ]; then
             echo "AUTO-LOCK-STATUS: ENABLED (xautolock ≤15 min)"
           else
             echo "AUTO-LOCK-STATUS: TIMEOUT-TOO-LONG (${xautolock_time} min)"
           fi
         fi
       fi
     else
       echo "No auto-lock daemons running"
     fi
   fi

   # Check XFCE/LXDE power manager settings
   echo ""
   echo "=== X11/XFCE Power Manager Settings ==="
   if command -v xfconf-query >/dev/null 2>&1; then
     # XFCE screensaver settings
     lock_enabled=$(xfconf-query -c xfce4-screensaver -p /lock/enabled 2>/dev/null || echo "not-found")
     if [ "$lock_enabled" != "not-found" ]; then
       echo "XFCE Screensaver lock enabled: $lock_enabled"
       idle_delay=$(xfconf-query -c xfce4-screensaver -p /timeout 2>/dev/null || echo "unknown")
       echo "XFCE Screensaver timeout: $idle_delay minutes"

       if [ "$lock_enabled" = "true" ] && [ "$idle_delay" != "unknown" ]; then
         SL_DE_STATUS_XFCE="ENABLED"; SL_DE_SECONDS_XFCE=$((idle_delay * 60))
         if [ "$idle_delay" -le 15 ]; then
           echo "AUTO-LOCK-STATUS: ENABLED (XFCE ≤15 min)"
         else
           echo "AUTO-LOCK-STATUS: TIMEOUT-TOO-LONG (${idle_delay} min)"
         fi
       else
         echo "AUTO-LOCK-STATUS: DISABLED"
         SL_DE_STATUS_XFCE="DISABLED"
       fi
     fi
   else
     echo "xfconf-query not available (not XFCE)"
   fi

   # Check KDE Plasma settings
   if command -v kreadconfig5 >/dev/null 2>&1 || command -v kreadconfig6 >/dev/null 2>&1; then
     echo ""
     echo "=== KDE Plasma Screen Lock Settings ==="
     kde_cmd="kreadconfig5"
     command -v kreadconfig6 >/dev/null 2>&1 && kde_cmd="kreadconfig6"

     lock_enabled=$($kde_cmd --file kscreenlockerrc --group Daemon --key Autolock 2>/dev/null || echo "unknown")
     timeout=$($kde_cmd --file kscreenlockerrc --group Daemon --key Timeout 2>/dev/null || echo "unknown")

     if [ "$lock_enabled" != "unknown" ]; then
       echo "KDE Autolock enabled: $lock_enabled"
       if [ "$timeout" != "unknown" ]; then
         # kscreenlockerrc stores Timeout in minutes (the default is 5), not
         # seconds. Read as seconds, every value passed the 900 limit.
         timeout_min="$timeout"
         echo "KDE lock timeout: ${timeout_min} minutes"

         if [ "$lock_enabled" = "true" ] && [ "$timeout_min" -le 15 ]; then
           echo "AUTO-LOCK-STATUS: ENABLED (KDE ≤15 min)"
           SL_DE_STATUS_KDE="ENABLED"; SL_DE_SECONDS_KDE=$((timeout_min * 60))
         elif [ "$lock_enabled" = "true" ]; then
           echo "AUTO-LOCK-STATUS: TIMEOUT-TOO-LONG (${timeout_min} min)"
           SL_DE_STATUS_KDE="ENABLED"; SL_DE_SECONDS_KDE=$((timeout_min * 60))
         else
           echo "AUTO-LOCK-STATUS: DISABLED"
           SL_DE_STATUS_KDE="DISABLED"
         fi
       fi
     fi
   else
     echo "KDE settings not available"
   fi

   # Which of the above the verdict rests on. Appended last, so a reader of an
   # older file, and the fallback in check_screen_lock_status, are unaffected.
   echo ""
   hb_screen_lock_summary
 } > "$output/screenlock-info.txt"

 # The ruleset as the device has it. Evaluation reads this file and never
 # probes the machine it happens to run on.
 echo "Checking firewall ruleset..."
 hb_collect_firewall_evidence > "$output/firewall-info.txt" 2>&1

 # Generate OS and Kernel status report (includes EOL checking)
 echo "Analyzing OS and kernel versions..."
 if command -v jq >/dev/null 2>&1 && [[ -f "$output/lynis-report.json" ]]; then
   # Fetch latest release information
   fetch_os_releases .cache >/dev/null 2>&1 || echo "  Warning: Could not fetch latest release information"

   # Run OS/kernel status check
   generate_os_status_report "$output" .cache || echo "  Warning: Could not complete OS/kernel analysis"

   # Run OS update history check
   echo "Checking OS update history..."
   if [[ -f "$thisdir/lib/check-os-updates.sh" ]]; then
     bash "$thisdir/lib/check-os-updates.sh" "$output/os-update-history.txt" >/dev/null 2>&1 || echo "  Warning: Could not check OS update history"
   else
     echo "  Warning: check-os-updates.sh not found, skipping update history"
   fi

   # Generate asset inventory
   echo "Generating asset inventory..."
   generate_asset_inventory "$output" >/dev/null || echo "  Warning: Could not generate asset inventory"

   # The xlsx report also writes asset-inventory.json into the output
   # directory, which has to exist before the archive is created below - it is
   # what lets the collection server read the audit's findings instead of
   # deriving them again.
   generate_xlsx_asset_row_report "$output" >/dev/null || echo "  Warning: Could not generate xlsx asset row report"
 else
   echo "  Skipping OS/kernel analysis (jq not available or lynis report missing)"
 fi

 # Say plainly what the run determined about the serial. Without this the
 # client used to write "Not available" and nobody noticed until the dashboard
 # showed the asset as outstanding.
 echo ""
 echo "Hardware serial:"
 hb_serial_report_line
 echo ""

 tar czf $tarball $output

# Fix ownership when running with sudo (tarball and output should belong to actual user, not root)
if [[ -n "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
  user_group=$(id -gn "$SUDO_USER" 2>/dev/null || echo "$SUDO_USER")
  chown -R "$SUDO_USER:$user_group" "$output" 2>/dev/null || true
  chown "$SUDO_USER:$user_group" "$tarball" 2>/dev/null || true
fi
}

make_command "submit" "Submit the audit archive to honeybadger-server"
submit(){
 # Parse arguments: an optional --config <file> and an optional archive.
 local tar_file="" config_file=""
 while [[ $# -gt 0 ]]; do
   case "$1" in
     --config)
       config_file="$2"
       if [[ -z "$config_file" ]]; then
         echo "ERROR: --config needs a file"
         exit 1
       fi
       shift 2
       ;;
     --config=*)
       config_file="${1#--config=}"
       shift
       ;;
     *)
       tar_file="$1"
       shift
       ;;
   esac
 done

 # If no file specified, find the most recent one
 if [[ -z "$tar_file" ]]; then
   echo "No tar file specified, searching for most recent..."
   tar_file=$(find_latest_tar)
   if [[ $? -ne 0 ]]; then
     echo "ERROR: No tar files found. Run audit first or specify a tar file."
     echo ""
     echo "Usage: ./RUNME.sh submit [--config <file>] [tar-file]"
     echo "Example: ./RUNME.sh submit honeybadger-hostname-user-20-03-2026.tar.gz"
     echo ""
     echo "Or run an audit first:"
     echo "  sudo ./RUNME.sh audit"
     exit 1
   fi
   echo "Found: $tar_file"
   echo ""
 fi

 # Validate file exists
 if [[ ! -f "$tar_file" ]]; then
   echo "ERROR: File not found: $tar_file"
   echo ""
   echo "Usage: ./RUNME.sh submit [--config <file>] [tar-file]"
   echo "Example: ./RUNME.sh submit honeybadger-hostname-user-20-03-2026.tar.gz"
   echo ""
   echo "Available tar files:"
   ls -t honeybadger-*.tar.gz honeybadger-*.tar 2>/dev/null || echo "  (none found)"
   exit 1
 fi

 echo "======================================"
 echo "Submitting tar archive to server"
 echo "======================================"
 echo ""

 # Load configuration
 if ! load_server_config "$config_file"; then
   exit 1
 fi
 echo ""

 # Check if submission is enabled
 if [[ "$SERVER_ENABLED" != "true" ]]; then
   echo "Server submission is disabled (SERVER_ENABLED=false)"
   echo "To enable, set SERVER_ENABLED=true in configuration file"
   echo "Configuration locations:"
   echo "  - ./.honeybadger.conf (current directory)"
   echo "  - ~/.honeybadger.conf (user home)"
   echo "  - /etc/honeybadger.conf (system-wide)"
   exit 0
 fi

 # Check if token is configured
 if [[ -z "$SERVER_TOKEN" ]]; then
   echo "ERROR: SERVER_TOKEN is required but not configured"
   echo ""
   echo "The server requires authentication. Please add SERVER_TOKEN to your configuration file:"
   echo "  SERVER_TOKEN=hb_token_your_token_here"
   echo ""
   echo "Configuration locations:"
   echo "  - ./.honeybadger.conf (current directory)"
   echo "  - ~/.honeybadger.conf (user home)"
   echo "  - /etc/honeybadger.conf (system-wide)"
   exit 1
 fi

 # Submit tar file
 submit_tar_file "$tar_file"
 exit_code=$?

 echo ""
 if [[ $exit_code -eq 0 ]]; then
   echo "======================================"
   echo "Submission complete!"
   echo "======================================"
 else
   echo "======================================"
   echo "Submission failed"
   echo "======================================"
 fi

 exit $exit_code
}
make_command "submit-tar" "Deprecated alias for submit"
submit-tar(){
 # The single-report path is gone: it submitted to an endpoint with no concept
 # of a hardware serial, so its submissions could not be attributed to an asset.
 # This alias exists so scheduled jobs still calling submit-tar keep working
 # rather than failing in the way hardest to notice - a cron job printing an
 # error nobody reads.
 echo "WARNING: 'submit-tar' is deprecated and will be removed."
 echo "         Use './RUNME.sh submit' instead - it does exactly this."
 echo ""
 submit "$@"
}


make_command "check-output" "Check OS and kernel status from existing output"
check-output(){
 if [[ -z "$1" ]]; then
   echo "Usage: ./RUNME.sh check-output <output-directory|tarball.tar.gz|tarball.tar>"
   echo "Example: ./RUNME.sh check-output output-wtoorren-09-02-2026"
   echo "Example: ./RUNME.sh check-output honeybadger-wtoorren-09-02-2026.tar.gz"
   echo "Example: ./RUNME.sh check-output honeybadger-wtoorren-09-02-2026.tar"
   echo ""
   echo "This command generates ISO27001 compliance reports:"
   echo "  - honeybadger-{username}-{date}-compliance.md"
   echo "  - honeybadger-{username}-{date}-actions.md"
   exit 1
 fi

 local input="$1"
 local output_dir=""
 local cleanup_extracted=false
 # The name of the archive, when given one. A download from badgersbay carries
 # the asset ID and proof_file in its name, which the xlsx report reads.
 local archive_name=""

 # The reports apply configured thresholds (MIN_HARDENING_SCORE), so they read
 # the same configuration the audit does.
 load_server_config >/dev/null || exit 1

 # Helper function to extract tarball
 extract_tarball() {
   local tarball="$1"
   archive_name=$(basename "$tarball")

   # Detect compression format and set appropriate tar flags
   local list_flags=""
   local extract_flags=""
   if [[ "$tarball" == *.tar.gz ]]; then
     # Gzip compressed
     list_flags="tzf"
     extract_flags="xzf"
   elif [[ "$tarball" == *.tar ]]; then
     # Uncompressed
     list_flags="tf"
     extract_flags="xf"
   else
     echo "ERROR: Unsupported archive format: $tarball"
     exit 1
   fi

   # Separate statements so a failing `tar` is a failing `tar`: combined with
   # `local` the listing's exit status would be discarded and an unreadable
   # archive would continue on with an empty target directory name.
   local target_dir
   target_dir=$(tar $list_flags "$tarball" | head -1 | cut -f1 -d"/")
   if [[ -z "$target_dir" ]]; then
     echo "ERROR: Could not read the contents of $tarball"
     exit 1
   fi

   # Check if target directory already exists
   if [[ -d "$target_dir" ]]; then
     echo "WARNING: Directory '$target_dir' already exists."
     echo -n "Do you want to overwrite it? (y/n): "
     read answer

     if [[ "$answer" != "yes" && "$answer" != "y" && "$answer" != "Y" ]]; then
       echo "Aborted. Using existing directory instead."
       output_dir="$target_dir"
       cleanup_extracted=false
       return 0
     fi

     echo "Removing existing directory..."
     rm -rf "$target_dir"
   fi

   echo "Extracting..."
   tar $extract_flags "$tarball" || { echo "ERROR: Failed to extract $tarball"; exit 1; }

   if [[ ! -d "$target_dir" ]]; then
     echo "ERROR: Could not find extracted directory"
     exit 1
   fi

   echo "Extracted to: $target_dir"
   output_dir="$target_dir"
   cleanup_extracted=true
 }

 # Check if input is a directory
 if [[ -d "$input" ]]; then
   output_dir="$input"
   echo "Using existing directory: $output_dir"

 # Check if input is a tar.gz file
 elif [[ -f "$input" && "$input" == *.tar.gz ]]; then
   echo "Found tar.gz file: $input"
   extract_tarball "$input"

 # Check if input is a tar file
 elif [[ -f "$input" && "$input" == *.tar ]]; then
   echo "Found tar file: $input"
   extract_tarball "$input"

 # If input doesn't exist as directory, try to find corresponding archive
 else
   # Try to find archive with similar name
   local tarball_gz=""
   local tarball_plain=""

   # If input looks like a directory name, try to find matching archives
   if [[ "$input" =~ ^output- ]]; then
     # Convert output-user-date to honeybadger-user-date.tar.gz / .tar
     local basename="${input#output-}"
     tarball_gz="honeybadger-${basename}.tar.gz"
     tarball_plain="honeybadger-${basename}.tar"
   elif [[ "$input" =~ ^honeybadger- ]]; then
     # Add .tar.gz or .tar if not present
     if [[ "$input" != *.tar.gz && "$input" != *.tar ]]; then
       tarball_gz="${input}.tar.gz"
       tarball_plain="${input}.tar"
     else
       # Input already has extension, use as-is
       tarball_gz="$input"
       tarball_plain="$input"
     fi
   else
     # Just try adding .tar.gz or .tar
     tarball_gz="${input}.tar.gz"
     tarball_plain="${input}.tar"
   fi

   # Try .tar.gz first, then .tar
   if [[ -f "$tarball_gz" ]]; then
     echo "Directory not found, but found tar.gz: $tarball_gz"
     extract_tarball "$tarball_gz"
   elif [[ -f "$tarball_plain" ]]; then
     echo "Directory not found, but found tar: $tarball_plain"
     extract_tarball "$tarball_plain"
   else
     echo "ERROR: Could not find directory '$input', tar.gz file '$tarball_gz', or tar file '$tarball_plain'"
     exit 1
   fi
 fi

 # No system information, no analysis. Checked before anything is fetched or
 # written, so a directory in a retired format is left exactly as it was found.
 if ! require_fastfetch_json "$output_dir"; then
   if [[ "$cleanup_extracted" == true ]]; then
     rm -rf "$output_dir"
   fi
   exit 1
 fi

 # Fetch latest release information if cache doesn't exist or is old
 echo ""
 echo "Checking for latest release information..."
 fetch_os_releases .cache
 echo ""

 # Write the OS/kernel status report. Its severity is deliberately not carried
 # out as an exit status: an OS approaching end of life is a finding, and a
 # caller on a schedule must be able to tell that from a run that broke. The
 # severity is in os-kernel-status.txt and in the compliance report.
 generate_os_status_report "$output_dir" || echo "  Warning: Could not complete OS/kernel analysis"

 # Generate asset inventory
 echo ""
 echo "Generating asset inventory..."
 generate_asset_inventory "$output_dir"

 # Generate ISO27001 compliance report
 echo ""
 echo "Generating ISO27001 compliance report..."
 generate_compliance_report "$output_dir"

 # Generate Lynis actions report
 echo ""
 echo "Generating Lynis actions report..."
 generate_lynis_actions_report "$output_dir"

 # Generate ISO27001 asset-register row report
 echo ""
 echo "Generating XLSX asset row report..."
 generate_xlsx_asset_row_report "$output_dir" "$archive_name"

 # Cleanup extracted directory if we created it
 if [[ "$cleanup_extracted" == true ]]; then
   echo ""
   echo "Cleaning up extracted directory: $output_dir"
   rm -rf "$output_dir"
 fi

 # Notify user about report files
 echo ""
 echo "======================================"
 echo "ISO27001 Compliance Reports Generated"
 echo "======================================"
 echo ""
 echo "Generated files:"
 echo "  ✓ honeybadger-*-compliance.md (ISO27001 checklist)"
 echo "  ✓ honeybadger-*-actions.md (Lynis security actions)"
 echo "  ✓ honeybadger-*-xlsx.md (fields for the ISO27001 asset register)"
 echo ""

 # The reports were written. Anything that would make this a failed run - no
 # such directory or archive, no fastfetch.json - exited long before here.
 exit 0
}

make_command "fetch-releases" "Fetch latest OS release information"
fetch-releases(){
 fetch_os_releases "${1:-.cache}"
}

make_command "run-tests" "Run the shell test suite"
# Not named "test": that is a shell builtin, and shadowing it would change the
# meaning of every `test` call in the libraries this script sources.
run-tests(){
 bash "$thisdir/tests/run-tests.sh" "$@"
}

make_command "version" "Show the Honeybadger version"
# show_version writes the banner that also heads honeybadger-info.txt in every
# archive. This is its command form: without it the only way to ask a checkout
# which version it is was to know that internal name, or to read
# VERSION-honeybadger directly.
version(){
 show_version
}

##### PLACE YOUR COMMANDS ABOVE #####

runme
