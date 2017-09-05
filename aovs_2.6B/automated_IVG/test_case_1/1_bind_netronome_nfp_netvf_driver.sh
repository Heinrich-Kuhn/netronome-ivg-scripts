#!/bin/bash

# Delete all bridges
for br in $(ovs-vsctl list-br);
do
  ovs-vsctl --if-exists del-br $br
done



if [ -z “$1” ]; then
   IP=14.0.0.1
else
   IP=$1
fi

#Configure Interface
 
DPDK_DEVBIND=$(find /opt/netronome -iname dpdk-devbind.py | head -1)
if [ "$DPDK_DEVBIND" == "" ]; then
  echo "ERROR: could not find dpdk-devbind.py tool"
  exit -1
fi

PCIA="$(ethtool -i nfp_v0.35 | grep bus | cut -d ' ' -f 5)"

  echo $DPDK_DEVBIND --unbind nfp_netvf $PCIA
  $DPDK_DEVBIND --bind nfp_netvf $PCIA

  echo $DPDK_DEVBIND --bind nfp_netvf $PCIA
  $DPDK_DEVBIND --bind nfp_netvf $PCIA

echo $DPDK_DEVBIND --status
$DPDK_DEVBIND --status

#Assign IP

ETH=$($DPDK_DEVBIND --status | grep $PCIA | cut -d ' ' -f 4 | cut -d '=' -f 2)

ip a add $1/24 dev $ETH #change IP address to 14.0.0.2 for second host**
ip l set dev $ETH up
