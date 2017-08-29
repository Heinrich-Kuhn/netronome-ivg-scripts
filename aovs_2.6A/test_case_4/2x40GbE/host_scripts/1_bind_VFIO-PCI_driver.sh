#!/bin/bash


PCIA="$(ethtool -i sdn_v0.42 | grep bus | cut -d ' ' -f 5)"
PCIA2="$(ethtool -i sdn_v0.43 | grep bus | cut -d ' ' -f 5)"
interface_list=($PCIA $PCIA2)
driver=vfio-pci
# updatedb
DPDK_DEVBIND=$(find /opt/ -iname dpdk-devbind.py | head -1)
echo "loading driver"
modprobe $driver
echo "DPDK_DEVBIND: $DPDK_DEVBIND"
for interface in ${interface_list[@]};
do
  echo $DPDK_DEVBIND --bind $driver $interface
  $DPDK_DEVBIND --bind $driver $interface
done
echo $DPDK_DEVBIND --status
$DPDK_DEVBIND --status
