#!/bin/bash

#1_bind_netronome_nfp_netvf_driver.sh

#If no IP is passed, use a default IP of 14.0.0.1
if [ -z "$1" ]; then
   IP=14.0.0.1
   else
   IP=$1
fi

#Configure Interface
updatedb
DPDK_DEVBIND=$(locate dpdk-devbind.py | head -1)
PCIA="$(ethtool -i sdn_v0.40 | grep bus | cut -d ' ' -f 5)"

  echo $DPDK_DEVBIND --bind nfp_netvf $PCIA
  $DPDK_DEVBIND --bind nfp_netvf $PCIA

  echo $DPDK_DEVBIND --status
  $DPDK_DEVBIND --status

#Assign IP
ETH=$($DPDK_DEVBIND --status | grep $PCIA | cut -d ' ' -f 4 | cut -d '=' -f 2)

#UP link
ip a add $IP/24 dev $ETH
ip link set dev $ETH up
