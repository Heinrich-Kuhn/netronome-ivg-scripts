#!/bin/bash

#Install backing VM
VM_NAME=centos_backing

cpu_model=$(virsh capabilities | grep -o '<model>.*</model>' | head -1 | sed 's/\(<model>\|<\/model>\)//g')
virsh undefine $VM_NAME > /dev/null 2>&1
virt-install \
  --name $VM_NAME \
  --disk path=/var/lib/libvirt/images/CentOS-7-x86_64-GenericCloud-1708.qcow2,format=qcow2,bus=virtio,cache=none \
  --disk /var/lib/libvirt/images/user_data_1.img,device=cdrom \
  --ram 4012 \
  --vcpus 8 \
  --cpu $cpu_model \
  --network bridge=virbr0,model=virtio \
  --nographics \
  --debug \
  --accelerate \
  --os-type=linux \
  --os-variant=rhel7 \
  --noautoconsole \
  --import

#wait for VM to shutdown
echo -e  "${GREEN}Waiting for VM to shutdown...${NC}"
while [ "$(virsh list --all | grep $VM_NAME | awk '{print $3}')" == "running" ]; do
  sleep 2
done

echo -e "${GREEN}VM shut down${NC}"
echo
sleep 1

#Eject user_data_1.img
virsh change-media $VM_NAME /var/lib/libvirt/images/user_data_1.img --eject --config


