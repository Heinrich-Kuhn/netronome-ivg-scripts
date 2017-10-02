#!/bin/bash
ovs-ctl stop

lsmod | grep -iq vfio_pci && rmmod vfio_pci
lsmod | grep -iq igb_uio && rmmod igb_uio

# Uninstall Agilio OVS
if [[ -f "/opt/netronome/bin/agilio-ovs-uninstall.sh" ]]; then
echo "Starting uninstall process.."
/opt/netronome/bin/agilio-ovs-uninstall.sh -y
fi

# Double-check for failed uninstall
if [[ -f "/opt/netronome/bin/agilio-ovs-uninstall.sh" ]]; then
echo "Starting forced uninstall process.."
/opt/netronome/bin/agilio-ovs-uninstall.sh -p
fi

service apparmor stop
service apparmor teardown
service apparmor start
