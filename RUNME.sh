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
 checkdeps "lynis" "https://github.com/CISOfy/lynis"
 checkdeps "docker"
 checkdeps "sed"
 checkdeps "neofetch" "https://github.com/dylanaraps/neofetch"
 checkdeps "tar"
 checkdeps "jq"
 checkdeps "curl"

 deps_missing

 # Use SUDO_USER if running with sudo, otherwise use current user
 local actual_user="${SUDO_USER:-$(whoami)}"
 local hostname=$(hostname -s)

 output=output-${hostname}-${actual_user}-$(date +"%d-%m-%Y")
 tarball=honeybadger-${hostname}-${actual_user}-$(date +"%d-%m-%Y").tar.gz
 mkdir -p $output

 echo "Running Lynis audit..."
 lynis audit system || { echo "ERROR: Lynis audit failed"; exit 1; }

 # Check if Docker image needs rebuild (if Dockerfile is newer than image)
 echo "Checking Docker image..."
 local image_name="wearetechnative/lynis-report-converter:latest"

 if ! docker image inspect "$image_name" >/dev/null 2>&1; then
   echo "Building Docker image (first time)..."
   docker build -t "$image_name" . || { echo "ERROR: Docker build failed"; exit 1; }
 elif [ -f Dockerfile ] && [ Dockerfile -nt "$output" ]; then
   echo "Dockerfile changed, rebuilding image..."
   docker build -t "$image_name" . || { echo "ERROR: Docker build failed"; exit 1; }
 else
   echo "Using cached Docker image"
 fi

 # Convert Lynis report using optimized container
 echo "Converting Lynis report to JSON..."
 docker run --rm \
   --read-only \
   -v /var/log/lynis-report.dat:/data/lynis-report.dat:ro \
   "$image_name" 2>/dev/null > $output/lynis-report.json || { echo "ERROR: Report conversion failed"; exit 1; }
 # Run neofetch as actual user (not root) to capture correct username
 sudo -u "${SUDO_USER:-$(whoami)}" neofetch --off --stdout | jq -Rn '
   ([inputs | select(length>0)] |
    (.[0] | capture("^(?<user>[^@]+)@(?<hostname>\\S+)") // {}) +
    (.[1:] | map(select(contains(":"))) | map(capture("(?<key>[^:]+): (?<value>.*)")) | map({(.key|ascii_downcase|gsub(" "; "_")): .value}) | add // {})
   )' > $output/neofetch.json
 command -v lsb_release >/dev/null && lsb_release -a > "$output/lsb_release.txt"
 show_version > $output/honeybadger-info.txt
 checkBlockDevices > $output/blockdevices.txt

 # Collect hardware serial number (requires root)
 echo "Collecting hardware serial number..."
 if command -v dmidecode >/dev/null 2>&1; then
   dmidecode -s system-serial-number 2>/dev/null > "$output/hardware-serial.txt" || echo "Not available" > "$output/hardware-serial.txt"
 else
   echo "Not available" > "$output/hardware-serial.txt"
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
   if command -v gsettings >/dev/null 2>&1; then
     # Check if GNOME settings are available
     if gsettings list-schemas 2>/dev/null | grep -q "org.gnome.desktop.screensaver"; then
       lock_enabled=$(gsettings get org.gnome.desktop.screensaver lock-enabled 2>/dev/null || echo "unknown")
       idle_activation=$(gsettings get org.gnome.desktop.screensaver idle-activation-enabled 2>/dev/null || echo "unknown")
       idle_delay=$(gsettings get org.gnome.desktop.session idle-delay 2>/dev/null || echo "unknown")
       lock_delay=$(gsettings get org.gnome.desktop.screensaver lock-delay 2>/dev/null || echo "unknown")

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

       # Check if auto-lock is properly configured
       if [ "$lock_enabled" = "true" ] && [ "$idle_activation" = "true" ]; then
         echo "AUTO-LOCK-STATUS: ENABLED"
       else
         echo "AUTO-LOCK-STATUS: DISABLED"
       fi
     else
       echo "GNOME screensaver settings not available"
     fi
   else
     echo "gsettings command not found"
   fi
   echo ""

   echo "=== Hyprland/Sway Config Check ==="
   # Check Hyprland
   if [ -f "$HOME/.config/hypr/hyprland.conf" ]; then
     echo "Hyprland config found at $HOME/.config/hypr/hyprland.conf"
     grep -i "lock\|swaylock\|hyprlock" "$HOME/.config/hypr/hyprland.conf" 2>/dev/null || echo "No lock configuration found"
   fi

   # Check Sway
   if [ -f "$HOME/.config/sway/config" ]; then
     echo "Sway config found at $HOME/.config/sway/config"
     grep -i "lock\|swaylock" "$HOME/.config/sway/config" 2>/dev/null || echo "No lock configuration found"
   fi

   # Check hypridle config for auto-lock timeout
   if [ -f "$HOME/.config/hypr/hypridle.conf" ]; then
     echo ""
     echo "Hypridle config found at $HOME/.config/hypr/hypridle.conf"
     # Look for timeout settings
     timeout_line=$(grep -E "timeout.*=.*[0-9]+" "$HOME/.config/hypr/hypridle.conf" 2>/dev/null | head -1)
     if [ -n "$timeout_line" ]; then
       echo "$timeout_line"
       timeout_value=$(echo "$timeout_line" | grep -oP '\d+' | head -1)
       if [ -n "$timeout_value" ]; then
         echo "Auto-lock timeout: ${timeout_value} seconds ($(($timeout_value / 60)) minutes)"
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
     if [ -f "$HOME/.config/sway/config" ]; then
       echo ""
       echo "Checking swayidle configuration in Sway config..."
       swayidle_config=$(grep -A2 "exec.*swayidle" "$HOME/.config/sway/config" 2>/dev/null)
       if [ -n "$swayidle_config" ]; then
         echo "$swayidle_config"
         timeout_val=$(echo "$swayidle_config" | grep -oP 'timeout \K\d+' | head -1)
         if [ -n "$timeout_val" ]; then
           echo "Auto-lock timeout: ${timeout_val} seconds ($(($timeout_val / 60)) minutes)"
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

       # Try to extract xautolock timeout if running
       if echo "$running_procs" | grep -q "xautolock"; then
         xautolock_time=$(echo "$running_procs" | grep "xautolock" | grep -oP '\-time \K\d+')
         if [ -n "$xautolock_time" ]; then
           echo "xautolock timeout: ${xautolock_time} minutes"
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
         if [ "$idle_delay" -le 15 ]; then
           echo "AUTO-LOCK-STATUS: ENABLED (XFCE ≤15 min)"
         else
           echo "AUTO-LOCK-STATUS: TIMEOUT-TOO-LONG (${idle_delay} min)"
         fi
       else
         echo "AUTO-LOCK-STATUS: DISABLED"
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
         timeout_min=$((timeout / 60))
         echo "KDE lock timeout: ${timeout} seconds (${timeout_min} minutes)"

         if [ "$lock_enabled" = "true" ] && [ "$timeout" -le 900 ]; then
           echo "AUTO-LOCK-STATUS: ENABLED (KDE ≤15 min)"
         elif [ "$lock_enabled" = "true" ]; then
           echo "AUTO-LOCK-STATUS: TIMEOUT-TOO-LONG (${timeout_min} min)"
         else
           echo "AUTO-LOCK-STATUS: DISABLED"
         fi
       fi
     fi
   else
     echo "KDE settings not available"
   fi
 } > "$output/screenlock-info.txt"

 # Generate OS and Kernel status report (includes EOL checking)
 echo "Analyzing OS and kernel versions..."
 if command -v jq >/dev/null 2>&1 && [[ -f "$output/lynis-report.json" ]]; then
   # Fetch latest release information
   fetch_os_releases .cache >/dev/null 2>&1 || echo "  Warning: Could not fetch latest release information"

   # Run OS/kernel status check
   check_os_status "$output" .cache || echo "  Warning: Could not complete OS/kernel analysis"

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
 else
   echo "  Skipping OS/kernel analysis (jq not available or lynis report missing)"
 fi

 tar czf $tarball $output

# Fix ownership when running with sudo (tarball and output should belong to actual user, not root)
if [[ -n "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
  user_group=$(id -gn "$SUDO_USER" 2>/dev/null || echo "$SUDO_USER")
  chown -R "$SUDO_USER:$user_group" "$output" 2>/dev/null || true
  chown "$SUDO_USER:$user_group" "$tarball" 2>/dev/null || true
fi
}

make_command "submit" "Submit audit reports to honeybadger-server"
submit(){
 # Parse optional output directory parameter
 local output_dir="$1"

 # If no directory specified, find the most recent one
 if [[ -z "$output_dir" ]]; then
   echo "No output directory specified, searching for most recent..."
   output_dir=$(find_latest_output_dir)
   if [[ $? -ne 0 ]]; then
     echo "ERROR: Could not find any output-* directories"
     echo ""
     echo "Usage: ./RUNME.sh submit [output-directory]"
     echo "Example: ./RUNME.sh submit output-hostname-user-17-03-2026"
     echo ""
     echo "Or run an audit first:"
     echo "  sudo ./RUNME.sh audit"
     exit 1
   fi
   echo "Found: $output_dir"
   echo ""
 fi

 # Validate directory exists
 if [[ ! -d "$output_dir" ]]; then
   echo "ERROR: Output directory does not exist: $output_dir"
   echo ""
   echo "Usage: ./RUNME.sh submit [output-directory]"
   echo "Example: ./RUNME.sh submit output-hostname-user-17-03-2026"
   echo ""
   echo "Available directories:"
   ls -dt output-* 2>/dev/null || echo "  (none found)"
   exit 1
 fi

 # Submit all reports
 submit_all_reports "$output_dir"
 exit_code=$?

 exit $exit_code
}

make_command "submit-tar" "Submit tar archive to honeybadger-server"
submit-tar(){
 # Parse optional tar file parameter
 local tar_file="$1"

 # If no file specified, find the most recent one
 if [[ -z "$tar_file" ]]; then
   echo "No tar file specified, searching for most recent..."
   tar_file=$(find_latest_tar)
   if [[ $? -ne 0 ]]; then
     echo "ERROR: No tar files found. Run audit first or specify a tar file."
     echo ""
     echo "Usage: ./RUNME.sh submit-tar [tar-file]"
     echo "Example: ./RUNME.sh submit-tar honeybadger-hostname-user-20-03-2026.tar.gz"
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
   echo "Usage: ./RUNME.sh submit-tar [tar-file]"
   echo "Example: ./RUNME.sh submit-tar honeybadger-hostname-user-20-03-2026.tar.gz"
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
 load_server_config
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

 # Helper function to extract tarball
 extract_tarball() {
   local tarball="$1"

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

   local target_dir=$(tar $list_flags "$tarball" | head -1 | cut -f1 -d"/")

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

 # Fetch latest release information if cache doesn't exist or is old
 echo ""
 echo "Checking for latest release information..."
 fetch_os_releases .cache
 echo ""

 # Run the OS status check
 check_os_status "$output_dir"

 local exit_code=$?

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
 echo ""

 exit $exit_code
}

make_command "fetch-releases" "Fetch latest OS release information"
fetch-releases(){
 fetch_os_releases "${1:-.cache}"
}

##### PLACE YOUR COMMANDS ABOVE #####

runme
