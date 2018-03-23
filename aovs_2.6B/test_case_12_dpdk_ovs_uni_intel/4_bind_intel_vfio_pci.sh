#!/bin/bash
PCI=$(lspci -d 8086:1583 | awk 'NR==1 {print $1}')
if [ -z "$PCI" ]
then
    PCI=$(lspci -d 8086:1584 | awk 'NR==1 {print $1}')
fi
if [[ "$PCI" == *":"*":"*"."* ]]; then
    echo "PCI correct format"
elif [[ "$PCI" == *":"*"."* ]]; then
    echo "PCI corrected"
    PCI="0000:$PCI"
fi
echo $PCI

modprobe uio
IGB_UIO="$(find -name 'igb_uio.ko' | head -1)"
insmod $IGB_UIO

driver=igb_uio

DPDK_DEVBIND=$(find / -iname dpdk-devbind.py | head -1)
if [ "$DPDK_DEVBIND" == "" ]; then
  echo "ERROR: could not find dpdk-devbind.py tool"
  exit -1
fi

echo "loading driver"
modprobe $driver
echo "DPDK_DEVBIND: $DPDK_DEVBIND"
echo $DPDK_DEVBIND --bind $driver $PCI
$DPDK_DEVBIND --bind $driver $PCI

echo $DPDK_DEVBIND --status
$DPDK_DEVBIND --status

exit 0
