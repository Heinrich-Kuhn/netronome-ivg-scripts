#!/bin/bash

VM_NAME="centos_backing"
script_dir="$(dirname $(readlink -f $0))"

vm_mac_addr=$(virsh dumpxml $VM_NAME \
    | awk -F\' '/mac address/ {print $2}')

# Start VM
virsh start $VM_NAME \
    || exit -1

echo -e "VM is starting..."

counter=0
while : ; do
    sleep 1
    counter=$((counter + 1))
    ipaddr=$(arp -an \
        | sed -rn 's/^.*\((\S+)\)\sat\s(\S+)\s.*$/\1 \2/p' \
        | grep " $vm_mac_addr" \
        | cut -d ' ' -f 1 )
    if [ ! -z "$ipaddr" ]; then
        nc -w 2 -v $ipaddr 22 < /dev/null > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            break
        fi
    fi
    if [ $counter -gt 30 ]; then
        echo "ERROR: VM failed to start up"
        exit -1
    fi
done

echo "Copying setup scripts to VM at $ipaddr"

# Remove VM IP from known Hosts if present
ssh-keygen -R $ipaddr

# Copy Setup scripts to VM
sshopts=()
sshopts+=( "-l" "root" )
sshopts+=( "-o" "StrictHostKeyChecking=no" )
sshopts+=( "-o" "UserKnownHostsFile=/dev/null" )
sshcmd="ssh ${sshopts[@]}"

rsync -a \
    -e "$sshcmd" \
    $script_dir/vm_scripts \
    $ipaddr: \
    || exit -1

exit 0
