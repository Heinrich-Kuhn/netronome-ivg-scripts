#!/bin/bash

echo "Load driver and bind to VFs"

PCIA="$(ethtool -i nfp_v0.44 | grep bus | cut -d ' ' -f 5)"
PCIB="$(ethtool -i nfp_v0.45 | grep bus | cut -d ' ' -f 5)"
driver=vfio-pci
DPDK_DEVBIND=$(find /opt/netronome -iname dpdk-devbind.py | head -1)

modprobe $driver || exit -1

$DPDK_DEVBIND --bind $driver $PCIA || exit -1
$DPDK_DEVBIND --bind $driver $PCIB || exit -1

exit 0
