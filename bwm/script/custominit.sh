#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Usage: $0 <parameter>"
  exit 1
fi

if [ "$1" = "DAHUA" ]; then
  # load kernel mod
  os_version=$(uname -r)
  version_prefix=$(echo $os_version | cut -d'-' -f1)
  KO_DIR="/usr/share/bwm"
  
  matching_dirs=$(ls -d "$KO_DIR"/"$version_prefix"* 2>/dev/null | grep "$version_prefix")
  if [ -z "$matching_dirs" ]; then
    echo "Missing the required kernel module"
    exit 1
  fi
  lsmod | grep dhcifb
  if [ $? -ne 0 ]; then
    insmod $matching_dirs/dhcifb.ko
  fi
  lsmod | grep cls_dhcmatchall
  if [ $? -ne 0 ]; then
    insmod $matching_dirs/cls_dhcmatchall.ko
  fi
fi

exit 0
