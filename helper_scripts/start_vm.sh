#!/bin/bash

VM_NAME=$1

virsh start $VM_NAME \
    || exit -1

/root/IVG_folder/helper_scripts/await-vm-ipaddr.sh $VM_NAME \
    || exit -1

ipaddr=$(/root/IVG_folder/helper_scripts/get-vm-ipaddr.sh $VM_NAME)

exec ssh -o StrictHostKeyChecking=no -l root $ipaddr
