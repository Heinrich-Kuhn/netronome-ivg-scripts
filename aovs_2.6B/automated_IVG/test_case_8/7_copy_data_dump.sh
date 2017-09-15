#!/bin/bash

ip=$(arp -an | grep $(virsh dumpxml $1 | awk -F\' '/mac address/ {print $2}')| egrep -o '([0-9]{1,3}\.){3}[0-9]{1,3}')

# scp root@$ip:/root/pktgen-dpdk-pktgen-3.3.2/capture.txt /root/IVG_folder/


