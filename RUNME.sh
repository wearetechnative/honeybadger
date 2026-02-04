#!/usr/bin/env bash
#(C)2019-2022 Pim Snel - https://github.com/mipmip/RUNME.sh
CMDS=();DESC=();NARGS=$#;ARG1=$1;make_command(){ CMDS+=($1);DESC+=("$2");};usage(){ printf "\nUsage: %s [command]\n\nCommands:\n" $0;line="              ";for((i=0;i<=$(( ${#CMDS[*]} -1));i++));do printf "  %s %s ${DESC[$i]}\n" ${CMDS[$i]} "${line:${#CMDS[$i]}}";done;echo;};runme(){ if test $NARGS -eq 1;then eval "$ARG1"||usage;else usage;fi;}

##### PLACE YOUR COMMANDS BELOW #####

MISSING_DEPS=()
thisdir="$(dirname "$0")"

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
  echo "    by Pim, et al."
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
 tarball=honeybadger-$(whoami)-$(date +"%d-%m-%Y").tar.bz2
 mkdir -p $output
 docker rm lynis_converter 2> /dev/null
 sudo lynis audit system
 docker build -t kuznetsovv/lynis-report-converter .
 docker run -d --name lynis_converter kuznetsovv/lynis-report-converter
 sudo cp /var/log/lynis-report.dat /tmp
 sudo chmod 666 /tmp/lynis-report.dat
 docker cp /tmp/lynis-report.dat lynis_converter:/var/log/lynis-report.dat
 docker exec lynis_converter ./opt/lynis-report-converter-master/lynis-report-converter.pl -j > $output/lynis-report.json
 docker stop lynis_converter
 docker rm lynis_converter
 sudo rm /tmp/lynis-report.dat
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

 tar cjvf $tarball $output
}

##### PLACE YOUR COMMANDS ABOVE #####

runme
