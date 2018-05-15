#!/bin/bash

#Install scripts on VM
VM_NAME=ubuntu_backing

echo -e "${GREEN}Installing prerequisites${NC}"
ssh root@"$(arp -an | grep $(virsh dumpxml $VM_NAME  | awk -F\' '/mac address/ {print $2}')| egrep -o '([0-9]{1,3}\.){3}[0-9]{1,3}')" "/root/vm_scripts/0_setup.sh"

virsh shutdown $VM_NAME

#wait for VM to shutdown
while [ "$(virsh list --all | grep $VM_NAME | awk '{print $3}')" == "running" ]; do
  echo "VM is still running"
  sleep 2
done
sleep 1
virsh undefine $VM_NAME

#Cleanup user_data files
rm /var/lib/libvirt/images/user_data
rm /var/lib/libvirt/images/user_data_1.img

echo
echo -e "${GREEN}Base image created!${NC}"
echo

exit 0
