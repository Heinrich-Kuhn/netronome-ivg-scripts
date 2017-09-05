#!/bin/bash
VM_NAME=$1

# Remove vhostuser interface
EDITOR='sed -i "/<interface type=.vhostuser.>/,/<\/interface>/d"' virsh edit $VM_NAME
EDITOR='sed -i "/<hostdev mode=.subsystem. type=.pci./,/<\/hostdev>/d"' virsh edit $VM_NAME

# Add vhostuser interfaces
# nfp_v0.40 --> 0000:81:0d.1
# nfp_v0.41 --> 0000:81:0d.2

bus=$(ethtool -i nfp_v0.40 | grep bus-info | awk '{print $5}' | awk -F ':' '{print $2}')
EDITOR='sed -i "/<devices/a \<hostdev mode=\"subsystem\" type=\"pci\" managed=\"yes\">  <source> <address domain=\"0x0000\" bus=\"0x'${bus}'\" slot=\"0x0d\" function=\"0x0\"\/> <\/source>  <address type=\"pci\" domain=\"0x0000\" bus=\"0x00\" slot=\"0x06\" function=\"0x0\"\/> <\/hostdev>"' virsh edit $VM_NAME

EDITOR='sed -i "/<devices/a \<hostdev mode=\"subsystem\" type=\"pci\" managed=\"yes\">  <source> <address domain=\"0x0000\" bus=\"0x'${bus}'\" slot=\"0x0d\" function=\"0x1\"\/> <\/source>  <address type=\"pci\" domain=\"0x0000\" bus=\"0x00\" slot=\"0x07\" function=\"0x0\"\/> <\/hostdev>"' virsh edit $VM_NAME

sleep 5

virsh start $1
