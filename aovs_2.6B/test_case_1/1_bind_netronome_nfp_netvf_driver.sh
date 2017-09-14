#!/bin/bash

#1_bind_netronome_nfp_netvf_driver.sh

#Check if IP is passed
if [ -z “$1” ]; then
   echo "ERROR: No IP address was passed"
   echo "Example: ./1_bind_netronome_nfp_netvf_driver.sh 10.10.10.1"
   exit -1
   else
   IP=$1
fi

#Locate the dpdk-devbind.py script
updatedb
DPDK_DEVBIND=$(locate dpdk-devbind.py | head -1)

#Grab the PCI address of VF nfp_v0.40
PCIA="$(ethtool -i nfp_v0.40 | grep bus | cut -d ' ' -f 5)"
    
  #Bind the VF to nfp_netvf
  echo $DPDK_DEVBIND --bind nfp_netvf $PCIA
  $DPDK_DEVBIND --bind nfp_netvf $PCIA

  echo $DPDK_DEVBIND --status
  $DPDK_DEVBIND --status

#Get netdev name
ETH=$($DPDK_DEVBIND --status | grep $PCIA | cut -d ' ' -f 4 | cut -d '=' -f 2)

#Assign IP to netdev and up the interface
ip a add $IP/24 dev $ETH
ip link set dev $ETH up

exit 0
