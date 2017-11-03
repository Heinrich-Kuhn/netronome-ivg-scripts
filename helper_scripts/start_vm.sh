#!/bin/bash

VM_NAME=$1

virsh start $VM_NAME \
    || exit -1

echo -n "Booting up VM "

sleep 3

counter=0
while : ; do
    # The DHCP lease list may contain multiple entries out
    # of which some may be stale
    ipaddr_list=$(virsh net-dhcp-leases default \
        | sed -rn 's#^.*\sipv4\s+(\S+)/\S+\s+(\S+)\s.*$#\2 \1#p' \
        | grep -E "^$VM_NAME " \
        | cut -d ' ' -f 2 )
    # Try each IP address
    for ipaddr in $ipaddr_list ; do
        nc -w 1 $ipaddr 22 < /dev/null > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo
            # Exist out of the (2) nested loops
            break 2
        fi
    done
    counter=$((counter + 1))
    if [ $counter -gt 60 ]; then
        echo
        echo "ERROR: failed to access VM"
        exit -1
    fi
    echo -n "."
    sleep 1
done

exec ssh -o StrictHostKeyChecking=no root@$ipaddr
