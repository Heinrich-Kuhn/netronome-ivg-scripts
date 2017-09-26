#!/bin/bash

$VM_NAME=$1

ip=$(virsh net-dhcp-leases default | awk -v var="$VM_NAME" '$6 == var {print $5}' | cut -d"/" -f1)

scp root@$ip:/root/capture.txt /root/IVG_folder/
scp root@$ip:/root/parsed_data.txt /root/IVG_folder/


