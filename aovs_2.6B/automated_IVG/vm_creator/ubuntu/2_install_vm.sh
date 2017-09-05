#!/bin/bash

#Install VM
VM_NAME=ubuntu_backing

cpu_model=$(virsh capabilities | grep -o '<model>.*</model>' | head -1 | sed 's/\(<model>\|<\/model>\)//g')
virsh undefine $VM_NAME 2/dev/null
virt-install \
  --name $VM_NAME \
  --disk path=/var/lib/libvirt/images/ubuntu-16.04-server-cloudimg-amd64-disk1.img,format=qcow2,bus=virtio,cache=none \
  --disk /var/lib/libvirt/images/user_data_1.img,device=cdrom \
  --ram 4012 \
  --vcpus 8 \
  --cpu $cpu_model \
  --network bridge=virbr0,model=virtio \
  --nographics \
  --debug \
  --accelerate \
  --os-type=linux \
  --os-variant=ubuntu16.04 \
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


