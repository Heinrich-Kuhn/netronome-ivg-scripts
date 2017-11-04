#!/bin/bash

VM_NAME=$1

get_tool="/root/IVG_folder/helper_scripts/get-vm-ipaddr.sh"
msg=$($get_tool $VM_NAME)
if [ $? -ne 0 ]; then
    echo "$msg"
    exit -1
fi
ipaddr="$msg"

scp root@$ipaddr:/root/capture.txt /root/IVG_folder \
    || exit -1
scp root@$ipaddr:/root/parsed_data.txt /root/IVG_folder \
    || exit -1

exit 0
