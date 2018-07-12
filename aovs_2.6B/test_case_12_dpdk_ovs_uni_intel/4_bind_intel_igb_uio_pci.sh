#!/bin/bash
PCI=$(lspci -d 8086:158b | awk 'NR==1 {print $1}')

if [[ "$PCI" == *":"*":"*"."* ]]; then
    echo "PCI correct format"
elif [[ "$PCI" == *":"*"."* ]]; then
    echo "PCI corrected"
    PCI="0000:$PCI"
fi
echo $PCI

modprobe uio #TODO: why modprobe uio not igb_uio??
sleep 1
IGB_UIO="/opt/src/dpdk-stable-17.11.2/build/kmod/igb_uio.ko"
sleep 1
insmod $IGB_UIO #TODO: needs check for preload driver

driver=igb_uio

DPDK_DEVBIND=$(find / -iname dpdk-devbind.py | head -1)
if [ "$DPDK_DEVBIND" == "" ]; then
  echo "ERROR: could not find dpdk-devbind.py tool"
  exit -1
fi

echo "loading driver"
modprobe uio
echo "clearing bind"
echo $DPDK_DEBIND -u $PCI
$DPDK_DEVIND -u $PCI
echo "DPDK_DEVBIND: $DPDK_DEVBIND"
echo $DPDK_DEVBIND --bind $driver $PCI
$DPDK_DEVBIND --bind $driver $PCI

echo $DPDK_DEVBIND --status
$DPDK_DEVBIND --status

exit 0
