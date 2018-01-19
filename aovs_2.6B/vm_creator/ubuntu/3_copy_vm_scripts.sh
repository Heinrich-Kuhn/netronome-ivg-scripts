#!/bin/bash

#Start VM

VM_NAME="ubuntu_backing"
script_dir="$(dirname $(readlink -f $0))"

virsh start $VM_NAME \
    || exit -1

echo -n "Waiting for VM to boot "
counter=0
while [ $counter -lt 12 ];
do
    if [ $counter -gt 60 ]; then
        echo "ERROR: VM did not boot up"
        exit -1
    fi
    ipaddr=$(arp -an \
        | grep $(virsh dumpxml $VM_NAME \
            | awk -F\' '/mac address/ {print $2}') \
        | egrep -o '([0-9]{1,3}\.){3}[0-9]{1,3}')
    if [ ! -z "$ipaddr" ]; then
        nc -w 2 -v $ipaddr 22 < /dev/null > /dev/null 2>&1 \
            && break
    fi
    sleep 1
    counter=$((counter+1))
    echo -n "."
done

echo
echo "VM IP address: $ipaddr"

echo "Copying setup scripts to VM..."

#Remove VM IP from known Hosts if present
ssh-keygen -R $ipaddr

#Copy Setup scripts to VM
scp -o StrictHostKeyChecking=no \
    -r $script_dir/vm_scripts \
    root@$ipaddr:/root/ \
    || exit -1

exit 0
