#!/bin/bash

########################################################################
printf "%-10s %s %s\n" "Hostname" "$(hostname)"

########################################################################
. /etc/os-release || exit -1
printf "%-10s %s %s\n" "OS" "$NAME" "$VERSION"

########################################################################
printf "%-10s %s\n" "Kernel" "$(uname -r)"

########################################################################
manu=$(dmidecode --type system | sed -rn 's/^\s*Manufacturer: (.*)$/\1/p')
prod=$(dmidecode --type system | sed -rn 's/^\s*Product Name: (.*)$/\1/p')

printf "%-10s %s %s\n" "Server" "$manu" "$prod"

########################################################################
cpu=$(lscpu | sed -rn 's/^Model name:\s+(\S.*)$/\1/p')
cps=$(lscpu | sed -rn 's/^Core.*per socket:\s+(\S.*)$/\1/p')
scn=$(lscpu | sed -rn 's/^Socket.*:\s+(\S.*)$/\1/p')

printf "%-10s %s (%s)\n" "CPU" "$cpu" \
  "$scn sockets, $cps cores/socket"

########################################################################
mem=$(cat /proc/meminfo | sed -rn 's/^MemTotal:\s+(\S.*)$/\1/p')
printf "%-10s %s\n" "Mem" "$mem"

########################################################################
ovsctl="/opt/netronome/bin/ovs-ctl"
if [ -x "$ovsctl" ]; then
  agvers=$($ovsctl version | sed -rn 's/^Netro.*version //p')
  printf "%-10s %s\n" "Agilio" "$agvers"
fi

########################################################################
hwinfo="/opt/netronome/bin/nfp-hwinfo"
if [ -x $hwinfo ]; then
  model=$(  $hwinfo | sed -rn 's/^assembly.model=(.*)$/\1/p')
  partno=$( $hwinfo | sed -rn 's/^assembly.partno=(.*)$/\1/p')
  rev=$(    $hwinfo | sed -rn 's/^assembly.revision=(.*)$/\1/p')
  sn=$(     $hwinfo | sed -rn 's/^assembly.serial=(.*)$/\1/p')
  bsp=$(    $hwinfo | sed -rn 's/^board.setup.version=(.*)$/\1/p')
  printf "%-10s %s (%s)\n" "NFP" "$model" "$partno rev=$rev sn=$sn"
  printf "%-10s %s %s\n" "BSP" "$bsp"
fi

########################################################################
lscpu | sed -rn 's/^NUMA node(.) CPU.*:\s+(\S+)$/CPU \1      \2/p'

########################################################################
nfpsys="/sys/bus/pci/drivers/nfp"
nfpnuma="UNKNOWN"
nfpbdf="UNKNOWN"
if [ -d "$nfpsys" ]; then
  nfpbdf=$(find $nfpsys -name '00*' | sed -r 's#^.*/##')
  if [ -h "$nfpsys/$nfpbdf" ]; then
    nfpnuma="$(cat $nfpsys/$nfpbdf/numa_node)"
  fi
  printf "%-10s %s\n" "NFP NUMA" "$nfpnuma"
  printf "%-10s %s\n" "NFP BDF"  "$nfpbdf"
fi

########################################################################
echo "-- Kernel Command Line"
cat /proc/cmdline

########################################################################
viopid=$(pgrep virtiorelayd)
if [ "$viopid" != "" ]; then
  echo "-- VirtIO Relay Daemon Command Line"
  cat /proc/$viopid/cmdline | tr '\0' ' '
  echo
fi

########################################################################
virsh="$(which virsh)"
if [ "$virsh" != "" ]; then
  echo "-- VM CPU Usage"
  for inst in $(virsh list --name) ; do
    if [ "$inst" != "" ]; then
      vcpulist=$($virsh vcpuinfo $inst \
        | sed -rn 's/^CPU:\s+(\S+)$/\1/p' \
        | tr '\n' ',' \
        | sed -r 's/,$/\n/' )
      printf "%-20s %s\n" "$inst" "$vcpulist"
    fi
  done
fi

########################################################################
exit 0