#!/bin/bash

VXLAN=$1

export DPDK_BASE_DIR=/root
export PKTGEN=/root/pktgen-3.4.1
script_dir="$(dirname $(readlink -f $0))"
cd $PKTGEN

CPU_COUNT=$(cat /proc/cpuinfo | grep processor | wc -l)

#Check for virtIO-relay interfaces on bus 1, otherwise, it will be SR-IOV interfaces
lspci | grep 01:
if [ $? == 1 ]; then
NETRONOME_VF_LIST=$(lspci -d 19ee: | awk '{print $1}')
else
NETRONOME_VF_LIST=$(lspci | grep 01: | awk '{print $1}')
fi

memory="--socket-mem 1440"
lcores="-l 0-$((CPU_COUNT-1))"

# whitelist
whitelist=""
for netronome_vf in ${NETRONOME_VF_LIST[@]};
do
  echo "netronome_vf: $netronome_vf"
  whitelist="$whitelist $netronome_vf"
done

# cpumapping
cpu_counter=0
port_counter=0
mapping=""
for netronome_vf in ${NETRONOME_VF_LIST[@]};
do
  echo "netronome_vf: $netronome_vf"
  mapping="${mapping}-m "
  
    cpu_counter=$((cpu_counter+1))
    echo "cpu_counter: $cpu_counter"
    mapping="${mapping}${cpu_counter}"
    
  mapping="${mapping}.${port_counter} "
  port_counter=$((port_counter+1))
done

echo "whitelist: $whitelist"
echo "mapping: $mapping"

if [ "$VXLAN" == "n" ]; then
$PKTGEN/dpdk-pktgen $lcores --proc-type auto $memory -n 4 --log-level=7 $whitelist --file-prefix=dpdk0_ -- $mapping -N -f $script_dir/unidirectional_transmitter.lua
fi

if [ "$VXLAN" == "y" ]; then
$PKTGEN/dpdk-pktgen $lcores --proc-type auto $memory -n 4 --log-level=7 $whitelist --file-prefix=dpdk0_ -- $mapping -N -f $script_dir/unidirectional_transmitter_vxlan.lua
fi

reset
