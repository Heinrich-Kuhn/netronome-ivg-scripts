#!/bin/bash

#Install backing VM
VM_NAME="centos_backing"

CLOUD_IMAGE_FILE="/var/lib/libvirt/images/CentOS-7-x86_64-GenericCloud-1708.qcow2"

BASE_IMAGE_NAME="CentOS-base"
BASE_IMAGE_FILE="/var/lib/libvirt/images/$BASE_IMAGE_NAME.qcow2"

if [ ! -f $CLOUD_IMAGE_FILE ]; then
    echo "ERROR: missing Cloud image file $CLOUD_IMAGE_FILE"
    exit -1
fi

# Delete existing Base Image file
if [ -f $BASE_IMAGE_FILE ]; then
    echo "Deleting existing CentOS Base Image file"
    rm -f $BASE_IMAGE_FILE
fi

# Create a copy of the downloaded Cloud Image file
cp -f $CLOUD_IMAGE_FILE $BASE_IMAGE_FILE \
    || exit -1

virsh undefine $VM_NAME > /dev/null 2>&1

cpu_model=$(virsh capabilities | grep -o '<model>.*</model>' | head -1 | sed 's/\(<model>\|<\/model>\)//g')
virt-install \
    --name $VM_NAME \
    --disk path=$BASE_IMAGE_FILE,format=qcow2,bus=virtio,cache=none \
    --disk /var/lib/libvirt/images/user_data_1.img,device=cdrom \
    --ram 4012 \
    --vcpus 8 \
    --cpu $cpu_model \
    --network bridge=virbr0,model=virtio \
    --graphics vnc \
    --accelerate \
    --os-type=linux \
    --os-variant=rhel7 \
    --noautoconsole \
    --import \
    || exit -1

# Wait for VM to shutdown
echo -e  "Waiting for VM to shutdown..."
while [ "$(virsh list --all | grep $VM_NAME | awk '{print $3}')" == "running" ]; do
    sleep 2
done

echo "VM shut down"
echo
sleep 1

# Eject user_data_1.img
virsh change-media $VM_NAME /var/lib/libvirt/images/user_data_1.img --eject --config \
    || exit -1

rm /var/lib/libvirt/images/user_data
rm /var/lib/libvirt/images/user_data_1.img

exit 0
