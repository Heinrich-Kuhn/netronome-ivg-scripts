#!/bin/bash

DRIVER=igb_uio
mp=uio
whitelist=""

lspci | grep 01:
if [ $? = 1 ]; then
  NETRONOME_VF_LIST=$(lspci -d 19ee: | awk '{print $1}')
else
  NETRONOME_VF_LIST=$(lspci | grep 01: | awk '{print $1}')
fi

DPDK_DEVBIND=$(readlink -f $(find /root/ -name "dpdk-devbind.py" | head -1))
DRKO=$(find ~ -iname 'igb_uio.ko' | head -1 )

echo $NETRONOME_VF_LIST
modprobe $mp
insmod $DRKO

for netronome_vf in ${NETRONOME_VF_LIST[@]};
do
  echo "netronome_vf: $netronome_vf"
  $DPDK_DEVBIND --bind $DRIVER $netronome_vf
  whitelist="$whitelist $netronome_vf"
done

echo "whitelist: $whitelist"
exit 0

