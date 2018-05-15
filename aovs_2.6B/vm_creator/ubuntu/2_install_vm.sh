#!/bin/bash

#Install backing VM
VM_NAME=ubuntu_backing

cpu_model=$(virsh capabilities | grep -o '<model>.*</model>' | head -1 | sed 's/\(<model>\|<\/model>\)//g')

# Shutdown/undefine previous VM with the same name
$IVG_dir/helper_scripts/delete-vms.sh --name "$VM_NAME" \
    || exit -1

virt-install \
  --name $VM_NAME \
  --disk path=/var/lib/libvirt/images/ubuntu-17.10-server-cloudimg-amd64.img,format=qcow2,bus=virtio,cache=none \
  --disk /var/lib/libvirt/images/user_data_1.img,device=cdrom \
  --ram 6144 \
  --vcpus 10 \
  --cpu $cpu_model \
  --network bridge=virbr0,model=virtio \
  --nographics \
  --debug \
  --accelerate \
  --os-type=linux \
  --os-variant=ubuntu16.04 \
  --noautoconsole \
  --import \
  || exit -1

#wait for VM to shutdown
echo -n "Waiting for VM to shutdown"
while : ; do
    state=$(virsh list --all \
        | grep $VM_NAME \
        | awk '{print $3}')
    if [ "$state" != "running" ]; then
        break
    fi
    sleep 1
    echo -n "."
done

echo " DOWN"

sleep 1

#Eject user_data_1.img
virsh change-media $VM_NAME \
    /var/lib/libvirt/images/user_data_1.img \
    --eject --config \
    || exit -1

exit 0

