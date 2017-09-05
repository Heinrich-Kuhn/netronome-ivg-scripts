#!/bin/bash

LIBVIRT_DIR=/var/lib/libvirt/images
basefile=$LIBVIRT_DIR/CentOS-7-x86_64-GenericCloud.qcow2
read -p "Enter a name for VM: " VM_NAME

cat <<- EOF > /tmp/ifcfg-eth0
DEVICE="eth0"
ONBOOT="yes"
IPV6INIT="no"
BOOTPROTO="dhcp"
TYPE="Ethernet"
EOF

if [ -f /etc/redhat-release ]; then
  yum -y install libguestfs-tools
fi

if [ -f /etc/lsb-release ]; then
  apt-get -y install libguestfs-tools
fi
  
echo "create overlay image"
overlay=$LIBVIRT_DIR/$VM_NAME.qcow2
qemu-img create -b $basefile -f qcow2 $overlay
sleep 5
guestfish --rw -i -a $overlay write /etc/hostname $VM_NAME
echo "create domain"

  cpu_model=$(virsh capabilities | grep -o '<model>.*</model>' | head -1 | sed 's/\(<model>\|<\/model>\)//g')
  name=$VM_NAME
  virt-install \
    --name $name \
    --disk path=${overlay},format=qcow2,bus=virtio,cache=none \
    --ram 4096 \
    --vcpus 4 \
    --cpu $cpu_model \
    --network network=default \
    --nographics \
    --debug \
    --accelerate \
    --os-type=linux \
    --os-variant=rhel7 \
    --noautoconsole \
    --noreboot \
    --import



