#!/bin/bash

vmname="$1"

if [ "$vmname" == "" ]; then
    echo "ERROR: please specify VM name"
    exit -1
fi

virsh dominfo $vmname > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: VM does not exist"
    exit -1
fi

state=$(virsh dominfo $vmname \
    | sed -rn 's/^State:\s+(\S+)$/\1/p')
if [ "$state" != "running" ]; then
    echo "ERROR: VM is not running"
    exit -1
fi

# Extract the MAC address of the management interface from XML
vm_mgmt_iface_mac_addr=$(virsh dumpxml $vmname \
    | tr -d '\n' \
    | sed -r 's/(<interface)/\n\1/' \
    | sed -r 's/(\/interface>)/\1\n/' \
    | grep -E "^<interface type='network'" \
    | grep -E "network='default'" \
    | sed -rn "s/^.*mac\saddress='(\S+)'.*\$/\1/p" \
    )

if [ "$vm_mgmt_iface_mac_addr" == "" ]; then
    echo "ERROR: failed to extract MAC address from VM"
    exit -1
fi

# Get the IP address from the correct DHCP lease
ipaddr=$(virsh  net-dhcp-leases default \
    | gawk '{ print $3" "$5" "$6 }' \
    | grep -E " $vmname\$" \
    | grep -E "^$vm_mgmt_iface_mac_addr " \
    | cut -d ' ' -f 2 \
    | cut -d '/' -f 1 \
    )

if [ "$ipaddr" == "" ]; then
    echo "ERROR: no active lease"
    exit -1
fi

nc -w 1 $ipaddr 22 < /dev/null > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: VM is not responding on port 22"
    exit -1
fi

echo $ipaddr
exit 0
