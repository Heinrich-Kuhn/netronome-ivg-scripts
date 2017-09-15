#!/bin/bash

VM_NAME="$1"

counter=0
ipaddr=""
while : ; do
    if [ $counter -gt 90 ]; then
        echo "ERROR: could not reach $VM_NAME"
        exit -1
    fi

    # Find the most recent lease for the VM
    ipaddr=$(virsh net-dhcp-leases default \
        | grep "ipv4" \
        | sort \
        | awk -v var="$VM_NAME" '$6 == var {print $5}' \
        | cut -d"/" -f1 \
        | tail -1)

    if [ "$ipaddr" != "" ]; then
        nc $ipaddr 22 < /dev/null > /dev/null
        if [ "$?" == "0" ]; then
            break
        fi
    fi

    sleep 2
    counter=$(( counter + 2 ))
done

mkdir -p /var/run/vm/
echo "$ipaddr" > /var/run/vm/$VM_NAME.ipaddr

echo "DONE($(basename $0))"
exit 0
