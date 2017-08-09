#!/bin/bash


interface_list=(00:06.0 00:09.0)
driver=igb_uio
mp=uio
# updatedb
DPDK_DEVBIND=$(find ~ -iname dpdk-devbind.py | head -1)
DRKO=$(find ~ -iname 'igb_uio.ko' | grep dpdk-16.11 | head -1)
echo "loading driver"
modprobe $mp
insmod $DRKO
echo "DPDK_DEVBIND: $DPDK_DEVBIND"
for interface in ${interface_list[@]};
do
  echo $DPDK_DEVBIND --bind $driver $interface
  $DPDK_DEVBIND --bind $driver $interface
done
echo $DPDK_DEVBIND --status
$DPDK_DEVBIND --status
