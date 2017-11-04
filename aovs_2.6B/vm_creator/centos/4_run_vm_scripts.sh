#!/bin/bash

VM_NAME="centos_backing"

vm_mac_addr=$(virsh dumpxml $VM_NAME \
    | awk -F\' '/mac address/ {print $2}')

ipaddr=$(arp -an \
    | sed -rn 's/^.*\((\S+)\)\sat\s(\S+)\s.*$/\1 \2/p' \
    | grep " $vm_mac_addr" \
    | cut -d ' ' -f 1 )

sshopts=()
sshopts+=( "-l" "root" )
sshopts+=( "-o" "StrictHostKeyChecking=no" )
sshopts+=( "-o" "UserKnownHostsFile=/dev/null" )
sshcmd="ssh ${sshopts[@]}"

mkdir -p /var/log/ivg || exit -1

echo -e "Installing prerequisites"

$sshcmd $ipaddr "/root/vm_scripts/0_setup.sh" \
    | tee /var/log/ivg/setup-centos-vm-base.log \
    || exit -1

virsh shutdown $VM_NAME

# Wait for VM to shutdown
while [ "$(virsh list --all | grep $VM_NAME | awk '{print $3}')" == "running" ]; do
    sleep 1
done

echo "VM shutdown"

sleep 1

virsh undefine $VM_NAME

echo
echo -e "Base image created!"
echo

exit 0
