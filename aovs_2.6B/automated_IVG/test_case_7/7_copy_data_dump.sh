#!/bin/bash

ip=$(virsh net-dhcp-leases default | awk -v var="$1" '$6 == var {print $5}' | cut -d"/" -f1)
echo $ip
echo "Copy data dump"
scp root@$ip:/root/pktgen-dpdk-pktgen-3.3.2/capture.txt /root/IVG_folder/


