#!/bin/bash

PCIA="$(ethtool -i nfp_v0.41 | grep bus | cut -d ' ' -f 5)"
PCIB="$(ethtool -i nfp_v0.42 | grep bus | cut -d ' ' -f 5)"

# Bind VF's using vfio-pci driver
driver=vfio-pci

# updatedb
DPDK_DEVBIND=$(find /opt/netronome -iname dpdk-devbind.py | head -1)
echo "loading driver"
modprobe $driver
echo "DPDK_DEVBIND: $DPDK_DEVBIND"
echo $DPDK_DEVBIND --bind $driver $PCIA
$DPDK_DEVBIND --bind $driver $PCIA

echo $DPDK_DEVBIND --bind $driver $PCIB
$DPDK_DEVBIND --bind $driver $PCIB

echo $DPDK_DEVBIND --status
$DPDK_DEVBIND --status
