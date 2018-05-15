#!/bin/bash

vmname="$1"

if [ "$vmname" == "" ]; then
    echo "ERROR: please specify VM name"
    exit -1
fi

echo -n "Waiting for VM to boot "

get_tool="/root/IVG/helper_scripts/get-vm-ipaddr.sh"

counter=0
while : ; do
    msg=$($get_tool $vmname)
    if [ $? -eq 0 ] && [ "$msg" != "" ]; then
        break
    fi
    counter=$((counter + 1))
    if [ $counter -gt 60 ]; then
        echo
        echo "$msg"
        exit -1
    fi
    echo -n "."
    sleep 1
done

echo " UP"
exit 0
