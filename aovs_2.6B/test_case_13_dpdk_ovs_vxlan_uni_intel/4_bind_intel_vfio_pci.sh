#!/bin/bash

intel_pf=$(lspci -d 8086:1583 | awk 'NR==1 {print $1}')
if [ -z "$intel_pf" ]
then
    intel_pf=$(lspci -d 8086:1584 | awk 'NR==1 {print $1}')
fi

driver=vfio-pci

DPDK_DEVBIND=$(find / -iname dpdk-devbind.py | head -1)
if [ "$DPDK_DEVBIND" == "" ]; then
  echo "ERROR: could not find dpdk-devbind.py tool"
  exit -1
fi

echo "loading driver"
modprobe $driver
echo "DPDK_DEVBIND: $DPDK_DEVBIND"
echo $DPDK_DEVBIND --bind $driver $intel_pf
$DPDK_DEVBIND --bind $driver $intel_pf

echo $DPDK_DEVBIND --status
$DPDK_DEVBIND --status

exit 0
