#!/bin/bash

LIBVIRT_DIR=/var/lib/libvirt/images
basefile=$LIBVIRT_DIR/ubuntu-16.04-server-cloudimg-amd64-disk1.img
VM_NAME=$1

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

virsh destroy $VM_NAME > /dev/null 2>&1
virsh undefine $VM_NAME > /dev/null 2>&1

echo "create overlay image"
overlay=$LIBVIRT_DIR/$VM_NAME.qcow2
qemu-img create -b $basefile -f qcow2 $overlay
sleep 5
guestfish --rw -i -a $overlay write /etc/hostname $VM_NAME
echo "create domain"

cpu_model=$(virsh capabilities \
    | grep -o '<model>.*</model>' \
    | head -1 \
    | sed 's/\(<model>\|<\/model>\)//g')

virt-install \
    --name $VM_NAME \
    --disk path=${overlay},format=qcow2,bus=virtio,cache=none \
    --ram 4096 \
    --vcpus 4 \
    --cpu $cpu_model \
    --network network=default \
    --nographics \
    --debug \
    --accelerate \
    --os-type=linux \
    --os-variant=ubuntu16.04 \
    --noautoconsole \
    --noreboot \
    --import \
    || exit -1

echo "VM has been created!"
exit 0
