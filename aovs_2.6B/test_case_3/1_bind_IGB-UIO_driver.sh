#!/bin/bash
#1_bind_IGB-UIO_driver.sh


PCIA1="$(ethtool -i nfp_v0.39 | grep bus | cut -d ' ' -f 5)"
PCIA2="$(ethtool -i nfp_v0.40 | grep bus | cut -d ' ' -f 5)"

interface_list=($PCIA1 $PCIA2)
driver=igb_uio
mp=uio
# updatedb
DPDK_DEVBIND=$(find /opt/ -iname dpdk-devbind.py | head -1)
DRKO=$(find /opt/ -iname 'igb_uio.ko' | head -1 )
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
