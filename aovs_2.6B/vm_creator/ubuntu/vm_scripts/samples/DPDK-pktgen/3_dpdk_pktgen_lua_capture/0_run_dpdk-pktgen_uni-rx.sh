#!/bin/bash

export DPDK_BASE_DIR=/root
export PKTGEN=/root/pktgen-3.4.1
script_dir="$(dirname $(readlink -f $0))"
cd $PKTGEN

CPU_COUNT=$(cat /proc/cpuinfo | grep processor | wc -l)

#Check for virtIO-relay interfaces on bus 1, otherwise, it will be SR-IOV interfaces
#lspci | grep 01:
#if [ $? == 1 ]; then
#NETRONOME_VF_LIST=$(ls /sys/bus/pci/drivers/igb_uio/ | grep 000)
#lse
#NETRONOME_VF_LIST=$(lspci -d 19ee: | awk '{print $1}')
#i

NETRONOME_VF_LIST=$(ls /sys/bus/pci/drivers/igb_uio/ | grep 000)

memory="--socket-mem 1440"
lcores="-l 0-$((CPU_COUNT-1))"

# whitelist
whitelist=""
for netronome_vf in ${NETRONOME_VF_LIST[@]};
do
  echo "netronome_vf: $netronome_vf"
  whitelist="$whitelist -w $netronome_vf"
done

# cpumapping
cpu_counter=0
port_counter=0
mapping="-m "
for netronome_vf in ${NETRONOME_VF_LIST[@]};
do
  echo "netronome_vf: $netronome_vf"
  
  cpu_counter=$((cpu_counter+1))
  echo "cpu_counter: $cpu_counter"
  mapping="${mapping}${cpu_counter}.${port_counter},"
  
  port_counter=$((port_counter+1))
done

mapping=${mapping::-1}

echo "whitelist: $whitelist"
echo "mapping: $mapping"

$PKTGEN/dpdk-pktgen $lcores --proc-type auto $memory -n 4 --log-level=7 $whitelist --file-prefix=dpdk0_ -- $mapping -N -f $script_dir/unidirectional_receiver.lua

reset

echo "Test run complete"
exit 0


