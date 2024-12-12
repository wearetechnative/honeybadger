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
    echo "  install this program first"
  fi
}

function deps_missing(){
  if [ ${#MISSING_DEPS[@]} -gt 0 ]
  then
    exit 1
  fi
}

function checkOS {
  if [ -f /etc/lsb-release ]; then
    osType="linux"
  elif [ -f /System/Library/CoreServices/SystemVersion.plist ]; then
    osType="macos"
  else
    osType="other"
  fi
}

make_command "audit" "Run Audit Tool to create report"
audit(){

 show_version

 checkdeps "jq"
 checkdeps "lynis"
 checkdeps "docker"
 exit

 sudo lynis audit system
 docker build -t kuznetsovv/lynis-report-converter .
 docker run -d --name lynis_converter kuznetsovv/lynis-report-converter
 sudo cp /var/log/lynis-report.dat /tmp
 sudo chmod 666 /tmp/lynis-report.dat
 #docker ps
 docker cp /tmp/lynis-report.dat lynis_converter:/var/log/lynis-report.dat
 docker exec lynis_converter ./opt/lynis-report-converter-master/lynis-report-converter.pl -j >> lynis-report-$(whoami)-$(date +"%d-%m-%Y").json
 docker stop lynis_converter
 docker rm lynis_converter
 sudo rm /tmp/lynis-report.dat
}

##### PLACE YOUR COMMANDS ABOVE #####

runme
