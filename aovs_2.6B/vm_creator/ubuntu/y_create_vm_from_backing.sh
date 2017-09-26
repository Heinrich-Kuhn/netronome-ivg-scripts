#!/bin/bash

script_dir="$(dirname $(readlink -f $0))"

#When running manually
IVG_dir="$(echo $script_dir | sed 's/\(IVG\).*/\1/g')"
$IVG_dir/helper_scripts/vm_shutdown_all.sh
sleep 4

#When running in auto mode
/root/IVG_folder/helper_scripts/vm_shutdown_all.sh

LIBVIRT_DIR=/var/lib/libvirt/images
basefile=$LIBVIRT_DIR/ubuntu-16.04-server-cloudimg-amd64-disk1.img

#Check if VM name is passed
if [ -z "$1" ]; then
   echo "ERROR: Please pass a VM name as the first parameter of this script..."
   exit -1
   else
   VM_NAME=$1
fi

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
    --os-variant=ubuntu16.04 \
    --noautoconsole \
    --noreboot \
    --import

echo "VM has been created!"

