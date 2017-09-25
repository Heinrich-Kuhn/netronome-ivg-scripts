#!/bin/bash

PCIA="$(ethtool -i nfp_v0.1 | grep bus | cut -d ' ' -f 5)"

# Bind VF's using vfio-pci driver
driver=nfp_netvf

DPDK_DEVBIND=$(find /opt/netronome -iname dpdk-devbind.py | head -1)
if [ "$DPDK_DEVBIND" == "" ]; then
  echo "ERROR: could not find dpdk-devbind.py tool"
  exit -1
fi

echo "loading driver"
modprobe $driver
echo "DPDK_DEVBIND: $DPDK_DEVBIND"
echo $DPDK_DEVBIND --bind $driver $PCIA
$DPDK_DEVBIND --bind $driver $PCIA

echo $DPDK_DEVBIND --bind $driver $PCIB
$DPDK_DEVBIND --bind $driver $PCIB

echo $DPDK_DEVBIND --status
$DPDK_DEVBIND --status

exit 0

#Get netdev name
ETH=$($DPDK_DEVBIND --status | grep $PCIA | cut -d ' ' -f 4 | cut -d '=' -f 2)

#Assign IP to netdev and up the interface
ip a add $IP/24 dev $ETH
ip link set dev $ETH up

exit 0
