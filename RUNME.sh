#!/usr/bin/env bash #(C)2019-2022 Pim Snel - https://github.com/mipmip/RUNME.sh
CMDS=();DESC=();NARGS=$#;ARG1=$1;shift;ARGS="$@";make_command(){ CMDS+=($1);DESC+=("$2");};usage(){ printf "\nUsage: %s [command]\n\nCommands:\n" $0;line="              ";for((i=0;i<=$(( ${#CMDS[*]} -1));i++));do printf "  %s %s ${DESC[$i]}\n" ${CMDS[$i]} "${line:${#CMDS[$i]}}";done;echo;};runme(){ if test $NARGS -ge 1;then eval "$ARG1 $ARGS"||usage;else usage;fi;}

##### LOAD LIBRARIES #####

thisdir="$(dirname "$0")"

# Load library file
if [[ -f "$thisdir/_library" ]]; then
    source "$thisdir/_library"
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
  echo "    by Pim, Wouter, et al."
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

 show_version
 checkOS
 #checkdeps "jq"
 checkdeps "lynis" "https://github.com/CISOfy/lynis"
 checkdeps "docker"
 checkdeps "sed"
 checkdeps "neofetch" "https://github.com/dylanaraps/neofetch"
 checkdeps "tar"
 deps_missing

 output=output-$(whoami)-$(date +"%d-%m-%Y")
 tarball=honeybadger-$(whoami)-$(date +"%d-%m-%Y").tar.gz
 mkdir -p $output

 echo "Running Lynis audit..."
 sudo lynis audit system || { echo "ERROR: Lynis audit failed"; exit 1; }

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
 neofetch | perl -pe 's/\e\[[0-9;?]*[ -\/]*[@-~]//g' > $output/neofetch.txt
 command -v lsb_release >/dev/null && lsb_release -a > "$output/lsb_release.txt"
 show_version > $output/honeybadger-info.txt
 checkBlockDevices > $output/blockdevices.txt

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

   # Generate asset inventory
   echo "Generating asset inventory..."
   generate_asset_inventory "$output" >/dev/null || echo "  Warning: Could not generate asset inventory"

   # Generate warnings/suggestions report
   echo "Generating warnings and suggestions report..."
   generate_warnings_report "$output/lynis-report.json" "$output/lynis-report-warnings_fails" || echo "  Warning: Could not generate warnings report"
 else
   echo "  Skipping OS/kernel analysis (jq not available or lynis report missing)"
 fi

 tar czf $tarball $output
}

make_command "check-output" "Check OS and kernel status from existing output"
check-output(){
 if [[ -z "$1" ]]; then
   echo "Usage: ./RUNME.sh check-output <output-directory|tarball.tar.gz>"
   echo "Example: ./RUNME.sh check-output output-wtoorren-09-02-2026"
   echo "Example: ./RUNME.sh check-output honeybadger-wtoorren-09-02-2026.tar.gz"
   exit 1
 fi

 local input="$1"
 local output_dir=""
 local cleanup_extracted=false

 # Helper function to extract tarball
 extract_tarball() {
   local tarball="$1"
   local target_dir=$(tar tzf "$tarball" | head -1 | cut -f1 -d"/")

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
   tar xzf "$tarball" || { echo "ERROR: Failed to extract $tarball"; exit 1; }

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

 # If input doesn't exist as directory, try to find corresponding tar.gz
 else
   # Try to find tar.gz with similar name
   local tarball=""

   # If input looks like a directory name, try to find matching tar.gz
   if [[ "$input" =~ ^output- ]]; then
     # Convert output-user-date to honeybadger-user-date.tar.gz
     local basename="${input#output-}"
     tarball="honeybadger-${basename}.tar.gz"
   elif [[ "$input" =~ ^honeybadger- ]]; then
     tarball="$input"
     # Add .tar.gz if not present
     [[ "$tarball" != *.tar.gz ]] && tarball="${tarball}.tar.gz"
   else
     # Just try adding .tar.gz
     tarball="${input}.tar.gz"
   fi

   if [[ -f "$tarball" ]]; then
     echo "Directory not found, but found tar.gz: $tarball"
     extract_tarball "$tarball"
   else
     echo "ERROR: Could not find directory '$input' or tar.gz file '$tarball'"
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

 # Cleanup extracted directory if we created it
 if [[ "$cleanup_extracted" == true ]]; then
   echo ""
   echo "Cleaning up extracted directory: $output_dir"
   rm -rf "$output_dir"
 fi

 exit $exit_code
}

make_command "fetch-releases" "Fetch latest OS release information"
fetch-releases(){
 fetch_os_releases "${1:-.cache}"
}

##### PLACE YOUR COMMANDS ABOVE #####

runme
